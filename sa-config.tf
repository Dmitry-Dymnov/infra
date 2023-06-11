/*
Для примера указанная настройка для двух кластреров prod и тест, что бы добавить новый нужно в variable "k8s_clusters" 
добавить новый кластер в default, например:
variable "k8s_clusters" {
  default = {   
    k8s-prod = {
      url  = "https://k3s.local:6443"
    }
    k8s-test = {
      url  = "https://k3s.local:6443"
    }
    k8s-stage = {
      url  = "https://k8s-stage.local:6443"
    }
  }
}
и так же настройки для провайдера и переменные для токена. Переменную (пример K8S_STAGE_TOKEN) так же нужно добавить в файл .gitlab-ci.yml и в проект в Gitlab.
Пример:

#################_CLUSTER_K8S_STAGE_#################
provider "kubernetes" {
  alias     = "k8s-stage"
  host      = "https://k8s-stage.local:6443"
  token     = var.K8S_STAGE_TOKEN
  insecure  = true
}

variable "K8S_STAGE_TOKEN" {
    type        = string
    description = "k8s-stage cluster token"
}
*/

variable "k8s_clusters" {
  default = {   
    k8s-prod = {
      url  = "https://k3s.local:6443"
    }
    k8s-test = {
      url  = "https://k3s.local:6443"
    }
  }
}

#################_CLUSTER_K8S_TEST_#################
provider "kubernetes" {
  alias     = "k8s-test"
  host      = "https://k3s.local:6443"
  token     = var.K8S_TEST_TOKEN
  insecure  = true
}

variable "K8S_TEST_TOKEN" {
    type        = string
    description = "k8s-test cluster token"
}

#################_CLUSTER_K8S_PROD_#################
provider "kubernetes" {
  alias     = "k8s-prod"
  host      = "https://k3s.local:6443"
  token     = var.K8S_PROD_TOKEN
  insecure  = true
}

variable "K8S_PROD_TOKEN" {
    type        = string
    description = "k8s-prod cluster token"
}