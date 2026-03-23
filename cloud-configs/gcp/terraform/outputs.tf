output "redirector_public_ip" {
  value = google_compute_address.redirector_ip.address
}

output "mythic_private_ip" {
  value = google_compute_instance.service["mythic"].network_interface[0].network_ip
}

output "gophish_private_ip" {
  value = google_compute_instance.service["gophish"].network_interface[0].network_ip
}

output "evilginx_private_ip" {
  value = google_compute_instance.service["evilginx"].network_interface[0].network_ip
}

output "pwndrop_private_ip" {
  value = google_compute_instance.service["pwndrop"].network_interface[0].network_ip
}
