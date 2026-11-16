# Sync secrets and Kubernetes configuration to ricos-mac-mini.local
HOST="ricos-mac-mini"

# Zsh Secrets
echo "\n- Sync Zsh Secrets"
scp ~/.zshsecrets $HOST:~/.zshsecrets
scp ~/.zshsecrets $HOST:~/Documents/GitHub/ricoberger/dotfiles/.zshsecrets

# Kubernetes
echo "\n- Sync Kubernetes Configuration"
ssh $HOST "mkdir -p ~/.kube/cache"
scp ~/.kube/config $HOST:~/.kube/config
scp -r ~/.kube/cache/kubectl-grafana $HOST:~/.kube/cache/
