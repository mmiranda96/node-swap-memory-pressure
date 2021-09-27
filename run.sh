sed 's/{{MEMORY}}/$1/g' limit-$2.yaml.tmpl | kubectl create -f -
