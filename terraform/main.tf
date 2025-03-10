provider "aws" {
  region = "eu-west-1"
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "my-terraform-key"  # שם המפתח שיופיע ב-AWS
  public_key = tls_private_key.key.public_key_openssh
}

resource "local_file" "private_key" {
  content  = tls_private_key.key.private_key_pem
  filename = "${path.module}/private_key.pem"
}

resource "aws_instance" "app_server" {
  ami           = "ami-0694d931cee176e7d"  # Ubuntu 22.04 LTS
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name

  vpc_security_group_ids = [aws_security_group.app_sg.id]

  tags = {
    Name = "K8sServer"
  }

  user_data = <<-EOF
                #!/bin/bash
                # עדכון חבילות
                apt-get update
                apt-get upgrade -y

                # התקנת Docker
                apt-get install -y apt-transport-https ca-certificates curl software-properties-common
                curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                apt-get update
                apt-get install -y docker-ce docker-ce-cli containerd.io
                usermod -aG docker ubuntu

                # התקנת kubectl
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

                # התקנת Minikube
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube

                # הגדרת הרשאות וקבצים נדרשים
                mkdir -p /home/ubuntu/.kube
                chown -R ubuntu:ubuntu /home/ubuntu/.kube

                # הפעלת Minikube כמשתמש ubuntu
                su - ubuntu -c "minikube start --driver=docker --force --memory=1024 --cpus=1"

                # המתנה לאתחול Minikube
                sleep 60

                # יצירת קובץ yaml לפוד של Nginx
                cat > /home/ubuntu/nginx-pod.yaml << 'YAML'
                apiVersion: v1
                kind: Pod
                metadata:
                  name: nginx-pod
                  labels:
                    app: nginx
                spec:
                  containers:
                  - name: nginx
                    image: nginx:latest
                    ports:
                    - containerPort: 80
                YAML

                # יצירת קובץ yaml לשירות של Nginx
                cat > /home/ubuntu/nginx-service.yaml << 'YAML'
                apiVersion: v1
                kind: Service
                metadata:
                  name: nginx-service
                spec:
                  selector:
                    app: nginx
                  ports:
                  - port: 80
                    targetPort: 80
                  type: NodePort
                YAML

                # פריסת Nginx
                su - ubuntu -c "kubectl apply -f /home/ubuntu/nginx-pod.yaml"
                su - ubuntu -c "kubectl apply -f /home/ubuntu/nginx-service.yaml"

                # כתיבת פקודה להצגת כתובת ה-URL של Nginx
                echo '#!/bin/bash' > /home/ubuntu/get-nginx-url.sh
                echo 'minikube service nginx-service --url' >> /home/ubuntu/get-nginx-url.sh
                chmod +x /home/ubuntu/get-nginx-url.sh
                chown ubuntu:ubuntu /home/ubuntu/get-nginx-url.sh

                # הרצת הפקודה הנ"ל ושמירת התוצאה בקובץ
                su - ubuntu -c "/home/ubuntu/get-nginx-url.sh > /home/ubuntu/nginx-url.txt"

                echo "התקנה הושלמה!"
                EOF

    # פקודה שמגדירה את הרשאות הקובץ לאחר היצירה
    provisioner "local-exec" {
      command = "chmod 400 ${path.module}/private_key.pem"
    }

}

resource "aws_security_group" "app_sg" {
  name        = "app_sg"
  description = "Security group for application server"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

