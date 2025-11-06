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
        
        // --- Stage 2: Installazione Helm ---
        stage('Helm Install') {
            steps {
                script {
                    // Definisco il percorso del Chart appena scaricato
                    def chartPath = 'formazione_sou_k8s/formazione_sou_k8s' // Modifica il percorso se la cartella del Chart è diversa
                    def releaseName = 'flask-app-release'
                    def namespace = 'formazione-sou'
                    
                    
                    // 2. Eseguire l'installazione Helm
                    // Uso 'upgrade --install' per creare o aggiornare la release
                    sh "helm upgrade --install ${releaseName} ${chartPath} --namespace ${namespace} --set image.tag=latest"
                }
            }
        }
    }
}