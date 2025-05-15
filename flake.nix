{
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
		c3c.url = "github:c3lang/c3c";
	};
	outputs = inputs:
	let
		pkgs = import inputs.nixpkgs {};
	in {
		devShells.${builtins.currentSystem}.default = pkgs.mkShellNoCC {
			packages = with pkgs; [ gcc gnumake valgrind gdb inputs.c3c.packages.${builtins.currentSystem}.default ];
			LD_LIBRARY_PATH = with pkgs; ''$LD_LIBRARY_PATH:${
				lib.makeLibraryPath [
					libGL
					xorg.libX11
				]
			}'';
		};
	};
}
