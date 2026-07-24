{ pkgs, ... }:

{
  home.packages = [
    pkgs.kubectl
    pkgs.argo-workflows
    (pkgs.google-cloud-sdk.withExtraComponents [
      pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
  ];
}
