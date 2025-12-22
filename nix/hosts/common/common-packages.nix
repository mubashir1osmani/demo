{ input, pkgs, unstablePkgs, ... }:
let
    inherit (input) nixpkgs nixpkgs-unstable;
in 
{
    environment.systemPackages = with pkgs; [
        ## stable
        ansible
        drill
        figurine
        git
        htop
        iperf3
        just
        python3
        tree
        watch
        wget
        vim
        openssl
        
        # Database tools
        postgresql
        neo4j
        
        # Container tools
        docker
        docker-compose

        # requires nixpkgs.config.allowUnfree = true;
        vscode-extensions.ms-vscode-remote.remote-ssh
        
    ];
}