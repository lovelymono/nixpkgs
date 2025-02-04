{
  k3sVersion = "1.32.1+k3s1";
  k3sCommit = "6a322f122729e0e668ca67fd9f0e993541bdce49";
  k3sRepoSha256 = "00ljl6mzbyvyy25cz0k511wmm1zhllvz0l2ns72ic4xjg9sxq6zi";
  k3sVendorHash = "sha256-/VQslKifAKFo57Zut9F8jWWNuMRFlMgpGo/FoqutT7Q=";
  chartVersions = import ./chart-versions.nix;
  imagesVersions = builtins.fromJSON (builtins.readFile ./images-versions.json);
  k3sRootVersion = "0.14.1";
  k3sRootSha256 = "0svbi42agqxqh5q2ri7xmaw2a2c70s7q5y587ls0qkflw5vx4sl7";
  k3sCNIVersion = "1.6.0-k3s1";
  k3sCNISha256 = "0g7zczvwba5xqawk37b0v96xysdwanyf1grxn3l3lhxsgjjsmkd7";
  containerdVersion = "1.7.23-k3s2";
  containerdSha256 = "0lp9vxq7xj74wa7hbivvl5hwg2wzqgsxav22wa0p1l7lc1dqw8dm";
  criCtlVersion = "1.31.0-k3s2";
}
