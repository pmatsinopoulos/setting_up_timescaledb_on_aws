resource "terraform_data" "prepare_ebs_volume_for_writing" {
  depends_on = [aws_volume_attachment.timescaledb_volume_attachment]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = aws_instance.timescaledb.public_ip
    private_key = file("${path.module}/timescaledb.pem")
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "sudo file -s /dev/nvme1n1 | grep -q '/dev/nvme1n1: data$' && sudo mkfs -t xfs /dev/nvme1n1",
        "sudo mkdir /data",
        "sudo mount /dev/nvme1n1 /data",
        "sudo cp /etc/fstab /etc/fstab.bak",
        "echo \"UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1) /data xfs defaults,nofail 0 2\" | sudo tee -a /etc/fstab",
      ]
    )
  }
}
