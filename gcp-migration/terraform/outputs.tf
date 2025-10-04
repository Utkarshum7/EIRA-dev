output "network_names" {
  value = {
    vpc     = google_compute_network.vpc.name
    subnet  = google_compute_subnetwork.subnet.name
    region  = var.region
  }
}


