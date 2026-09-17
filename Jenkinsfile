pipeline {
    agent any

    options {
        timestamps()
        skipDefaultCheckout(true)
    }

    environment {
        IMAGE_NAME = 'mi-app-web'
        IMAGE_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'mi-contenedor-web'

        VM_IP = '192.168.1.100'
        VM_USER = 'deploy'
        SSH_CREDS = 'ssh-vm-destino'

        HOST_PORT = '80'
        CONTAINER_PORT = '80'

        IMAGE_ARCHIVE = "mi-app-web-${BUILD_NUMBER}.tar"
        REMOTE_ARCHIVE = "/tmp/mi-app-web-${BUILD_NUMBER}.tar"

        HEALTH_URL = 'http://localhost:80/'
    }

    stages {
        stage('Descargar código') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/bernardoguerra-utec/mi-proyecto-devops.git'
            }
        }

        stage('Construir imagen Docker') {
            steps {
                sh '''
                    docker build \
                      --pull \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -t ${IMAGE_NAME}:latest \
                      .
                '''
            }
        }

        stage('Empaquetar imagen') {
            steps {
                sh '''
                    docker save \
                      -o ${IMAGE_ARCHIVE} \
                      ${IMAGE_NAME}:${IMAGE_TAG}
                '''
            }
        }

        stage('Enviar imagen a VM destino') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: "${SSH_CREDS}",
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        scp \
                          -i "$SSH_KEY" \
                          -o StrictHostKeyChecking=no \
                          -o UserKnownHostsFile=/dev/null \
                          "${IMAGE_ARCHIVE}" \
                          "${SSH_USER}@${VM_IP}:${REMOTE_ARCHIVE}"
                    '''
                }
            }
        }

        stage('Desplegar y validar') {
            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: "${SSH_CREDS}",
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        ssh \
                          -i "$SSH_KEY" \
                          -o StrictHostKeyChecking=no \
                          -o UserKnownHostsFile=/dev/null \
                          "${SSH_USER}@${VM_IP}" \
                          "
                            set -eu

                            echo 'Cargando imagen nueva...'
                            docker load -i ${REMOTE_ARCHIVE}

                            PREVIOUS_IMAGE=\\\$(docker ps -a \
                              --filter name=^/${CONTAINER_NAME}\\\$ \
                              --format '{{.Image}}' \
                              | head -n 1 || true)

                            echo \\"Imagen anterior: \\\${PREVIOUS_IMAGE:-ninguna}\\"

                            echo 'Eliminando contenedor anterior...'
                            docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

                            echo 'Iniciando contenedor nuevo...'
                            docker run -d \
                              --name ${CONTAINER_NAME} \
                              --restart unless-stopped \
                              -p ${HOST_PORT}:${CONTAINER_PORT} \
                              ${IMAGE_NAME}:${IMAGE_TAG}

                            echo 'Ejecutando health check...'
                            HEALTH_OK=false

                            for i in 1 2 3 4 5; do
                              if curl -fsS ${HEALTH_URL} > /dev/null; then
                                HEALTH_OK=true
                                break
                              fi

                              echo \\"Intento \\\$i/5 fallido; esperando 5 segundos...\\"
                              sleep 5
                            done

                            if [ \\"\\\$HEALTH_OK\\" = 'true' ]; then
                              echo 'Health check exitoso. Nueva versión activa.'
                              docker image tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_NAME}:latest
                              rm -f ${REMOTE_ARCHIVE}
                              exit 0
                            fi

                            echo 'Health check falló. Iniciando rollback...'
                            docker rm -f ${CONTAINER_NAME} 2>/dev/null || true

                            if [ -n \\"\\\$PREVIOUS_IMAGE\\" ]; then
                              echo \\"Restaurando imagen anterior: \\\$PREVIOUS_IMAGE\\"
                              docker run -d \
                                --name ${CONTAINER_NAME} \
                                --restart unless-stopped \
                                -p ${HOST_PORT}:${CONTAINER_PORT} \
                                \\\$PREVIOUS_IMAGE
                            else
                              echo 'No existe una imagen previa para restaurar.'
                            fi

                            rm -f ${REMOTE_ARCHIVE}
                            exit 1
                          "
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Despliegue exitoso en http://${VM_IP}:${HOST_PORT}"
        }

        failure {
            echo 'El pipeline falló. Revisar los logs; se ejecutó rollback si existía una imagen previa.'
        }

        always {
            sh 'rm -f "${IMAGE_ARCHIVE}" || true'
            cleanWs(deleteDirs: true, notFailBuild: true)
        }
    }
}
