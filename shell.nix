{ pkgs ? import <nixpkgs> {} }:
let
	c3c = pkgs.callPackage ((pkgs.fetchFromGitHub {
		owner = "c3lang";
		repo = "c3c";
		rev = "f134b8b67a533eeb235bae5796fb8108b39e715a";
		sha256 = "sha256-mKLWj4JaJ+NV2t6T7MUVm6pgr8IofFsEuc82fQyCEFo=";
	} + "/nix")) {};
in
pkgs.mkShellNoCC {
	packages = with pkgs; [ gcc c3c ];
	LD_LIBRARY_PATH = with pkgs; ''$LD_LIBRARY_PATH:${
		lib.makeLibraryPath [
			libGL
			xorg.libX11
		]
	}'';
}

