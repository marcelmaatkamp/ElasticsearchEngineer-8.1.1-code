terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

locals {
  ELASTICSEARCH_VERSION = "8.13.0"
  KIBANA_VERSION        = "8.13.0"
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "docker_network" "elasticsearch" {
  name = "elasticsearch"
}

resource "docker_volume" "elasticsearch-data" {
  name = "elasticsearch-data"
}

# Pulls the image
resource "docker_container" "elasticsearch" {
  image    = "docker.elastic.co/elasticsearch/elasticsearch:${local.ELASTICSEARCH_VERSION}"
  name     = "elasticsearch"
  restart  = "always"
  networks_advanced {
    name = docker_network.elasticsearch.name
  }
  ulimit {
    name = "memlock"
    soft = -1
    hard = -1
  }
  ulimit {
    name = "nofile"
    soft = 65536
    hard = 65536
  }
  capabilities {
    add = ["IPC_LOCK"]
  }
  ports {
    internal = 9200
    external = 9200
  }
  env = [
    "xpack.security.enabled=false",
    "discovery.type=single-node"
  ]
  mounts {
    source = docker_volume.elasticsearch-data.name
    target = "/usr/share/elasticsearch/data"
    type   = "volume"
  }
}

resource "docker_container" "kibana" {
  image      = "docker.elastic.co/kibana/kibana:${local.KIBANA_VERSION}"
  name       = "kibana"
  depends_on = [docker_container.elasticsearch]
  restart    = "always"
  networks_advanced {
    name = docker_network.elasticsearch.name
  }
  env        = [
    "ELASTICSEARCH_URL=http://${docker_container.elasticsearch.name}:9200",
  ]
  ports {
    internal = 5601
    external = 5601
  }
}

