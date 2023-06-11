FROM hashicorp/terraform:1.4
RUN apk add --no-cache bash openldap-clients
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
RUN chmod +x /usr/local/bin/yq