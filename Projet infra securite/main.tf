provider "google" {
  credentials = file("<CHEMIN_VERS_VOTRE_FICHIER_JSON_DE_CREDENTIALS>")
  project     = "<VOTRE_ID_DE_PROJET>"
  region      = "us-central1" 
}

resource "google_container_cluster" "gke_cluster" {
  name     = "my-gke-cluster"
  location = "us-central1" 

  node_pool {
    name = "default-pool"
    initial_node_count = 1
    machine_type = "e2-medium"  
  }
}

resource "google_container_node_pool" "node_pool" {
  name       = "my-node-pool"
  location   = "us-central1"  
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 1
  node_config {
    machine_type = "e2-medium"  
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-deployment"
  }

  spec {
    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "nginx"
        }
      }
    }
  }
}

resource "kubernetes_deployment" "grafana" {
  metadata {
    name = "grafana-deployment"
  }

  spec {
    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        container {
          image = "grafana/grafana:latest"
          name  = "grafana"
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = "password123"  
          }
        }
      }
    }
  }
}

resource "google_cloud_scheduler_job" "daily_job" {
  name     = "daily-job"
  location = "us-central1"  

  schedule = "0 7 * * *"
  time_zone = "UTC"

  target {
    http_target {
      uri = google_container_node_pool.node_pool.endpoint
      http_method = "GET"
    }
  }
}

resource "google_cloudfunctions_function" "curl_function" {
  name        = "curl-function"
  runtime     = "nodejs14"
  source_archive_bucket = "<NOM_DU_BUCKET>"
  source_archive_object = "<CHEMIN_VERS_L'ARCHIVE_ZIP_DE_VOTRE_FONCTION>"

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_cloud_scheduler_job.daily_job.name
  }

  ingress_settings = "ALLOW_INTERNAL_ONLY"
  service_account_email = "<EMAIL_DU_SERVICE_ACCOUNT>"
}

resource "google_sql_database_instance" "postgres_instance" {
  name             = "my-postgres-instance"
  database_version = "POSTGRES_13"
  region           = "us-central1"  
  project          = "<VOTRE_ID_DE_PROJET>"
  settings {
    tier = "db-f1-micro"  
  }
}

resource "google_sql_database" "postgres_db" {
  name     = "my-database"
  instance = google_sql_database_instance.postgres_instance.name
}

resource "google_sql_user" "postgres_user" {
  name     = "my-user"
  instance = google_sql_database_instance.postgres_instance.name
  password = "password123"  
}



resource "google_compute_network" "mynetwork" {
  name                    = "mynetwork"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "mysubnetwork" {
  name          = "mysubnetwork"
  network       = google_compute_network.mynetwork.name
  ip_cidr_range = "10.0.0.0/24"
}

resource "google_compute_instance" "apache_vm" {
  name         = "apache-vm"
  machine_type = "e2-medium"  
  zone         = "us-central1-a"  

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mysubnetwork.name
  }

  metadata = {
    startup-script = <<-SCRIPT
      #!/bin/bash
      apt-get update
      apt-get install -y docker.io
      docker run -d -p 4000:80 httpd
    SCRIPT
  }
}

resource "google_compute_firewall" "apache_fw" {
  name    = "apache-fw"
  network = google_compute_network.mynetwork.name

  allow {
    protocol = "tcp"
    ports    = ["4000"]
  }
}
