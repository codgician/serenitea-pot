rec {
  # Keys
  hosts = {
    fischl = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDCFFJFcaGtTPeoI+A9MjZvyqIdrsZBIw7MOD4S7hQyJ" ];
    focalors = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM9elJzxtHicXWL+okluqOjCJ/ZcMlAuPqH/WyTnjfeW" ];
    furina = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOqianG6ZE67Tpy65/JlvUNJhQc7V4tK1UetkveKV6O3" ];
    jahoda = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBEOGfpFFrlBGu9ui/XWMhB4NxLcS1MNuL/ozxDYAhTZ" ];
    lumine = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICLgMH2GQZCfmXV2I4jlVHsM6PYiitT9hPRNhX40amKE" ];
    nahida = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID+oF/2GvNR5Adz0y6RiNTg8UrcneQSEWualML5wAwer" ];
    odette = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH2tLJh/Rdy/c/a5ZIblX90ZHHmrOBTOumzEonvs8gGa" ];
    paimon = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFljYcA+U1awv/K4xHx9pr8+WVH/YDAN73nPlEhE3zJr" ];
    raiden-ei = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIB0g+aVDhTxpSHq7XnLLZvK2Lm9nxLdBNggzyqrD2Hf" ];
    sandrone = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIviqrRjXSzpnF6Q6gRfLGWwYEq5FsDiTLlMwnlUDQmS" ];
    wanderer = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfDqA0dXPP7KLMLNNqSECrJ21mdspNotYqe1gkaJ7Kg" ];
    xianyun = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmOBQu1zv4bsSMw7uVvYkFhGz+jOUXwgJLOe8wAVz0P" ];
    zibai = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBz7WFyT4JCS8LkOnNhwBcaWuFnap1/x4VJFqBz4vXnP" ];
  };

  users = {
    codgi = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/Mohin9ceHn6zpaRYWi3LeATeXI7ydiMrP3RsglZ2r" ];
    shijiazhang = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOfYD3BnzqBK6FsxldFzSgwIWNBlfySRVI6dw7KQfGcn"
    ];
  };

  loginKeys = {
    codgi = users.codgi ++ [
      # Secure Enclave key on furina
      "sk-ecdsa-sha2-nistp256@openssh.com AAAAInNrLWVjZHNhLXNoYTItbmlzdHAyNTZAb3BlbnNzaC5jb20AAAAIbmlzdHAyNTYAAABBBOUwhW9s2miIEdEICF3d/QWjNQiBs90q89JbK/nIENWDRM0D9nirU/couH1AmlI3L+v9xDgibqHcqzg3rt85He8AAAAEc3NoOg=="
    ];
    shijiazhang = users.shijiazhang;
  };

}
