pipeline {
    agent any
    
    stages {
        
        // --- Stage 1: Scarica il Chart dalla repository K8s ---
        stage('Clone Helm Chart') {
            steps {
                git branch: 'main', 
                    credentialsId: 'git-creds', 
                    url: 'https://github.com/andreademarco/formazione_sou_k8s.git'
            }
        }
        
        stage('Setup Python Dependencies') {
            steps {
                sh 'python3 -m pip install --upgrade pip' // Aggiorna pip
                sh 'python3 -m pip install kubernetes'    // Installa il modulo K8s
            }  
        }  
        // --- Stage 2: Installazione Helm ---
        stage('Helm Install') {
            steps {
                script {
                    // Definisco il percorso del Chart appena scaricato
                    // NOTA: Se il chart è in una sottocartella, e.g., 'charts/flask-app-chart', il percorso va corretto.
                    def chartPath = 'flask-app-chart' 
                    def helmCommand = '/usr/local/bin/helm'
                    def minikubeCommand = '/usr/local/bin/minikube'
                    def kubectlCommand = '/usr/local/bin/kubectl'
                    def releaseName = 'flask-app-release'
                    def namespace = 'formazione-sou'
                    
                    // Configura il contesto Kubernetes (necessario se si usa kubectl/helm)
                    sh "${minikubeCommand} kubectl config set-context minikube"
                    
                    // 1. Creare il namespace (idempotente) 
                    sh "${kubectlCommand} create namespace ${namespace} --dry-run=client -o yaml | ${kubectlCommand} apply -f -"

                    sh 'ls -R' // check per vedere cosa è stato clonato

                    // 2. Eseguire l'installazione Helm
                    sh "${helmCommand} upgrade --install ${releaseName} ${chartPath} --namespace ${namespace} --set image.tag=latest"
                }
            }
        }
        
        // --- Stage 3: Esporta i Dettagli del Deployment ---
        stage('Export Deployment Details') {
            steps {
                script {
                    // Esegue lo script Python che sfrutta le variabili di ambiente/kubeconfig dell'agente Jenkins
                    sh "python3 export_deployment.py"
                }
            }
        }
    } // Chiusura di 'stages'
} // Chiusura di 'pipeline'
