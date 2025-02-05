{
  # To test your changes in androidEnv run `nix-shell android-sdk-with-emulator-shell.nix`

  # If you copy this example out of nixpkgs, use these lines instead of the next.
  # This example pins nixpkgs: https://nix.dev/tutorials/first-steps/towards-reproducibility-pinning-nixpkgs.html
  /*
    nixpkgsSource ? (builtins.fetchTarball {
      name = "nixpkgs-20.09";
      url = "https://github.com/NixOS/nixpkgs/archive/20.09.tar.gz";
      sha256 = "1wg61h4gndm3vcprdcg7rc4s1v3jkm5xd7lw8r2f67w502y94gcy";
    }),
    pkgs ? import nixpkgsSource {
      config.allowUnfree = true;
    },
  */

  # If you want to use the in-tree version of nixpkgs:
  pkgs ? import ../../../../.. {
    config.allowUnfree = true;
  },

  config ? pkgs.config,
  # You probably need to set it to true to express consent.
  licenseAccepted ?
    config.android_sdk.accept_license or (builtins.getEnv "NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE" == "1"),
}:

# Copy this file to your Android project.
let
  # If you copy this example out of nixpkgs, something like this will work:
  /*
    androidEnvNixpkgs = fetchTarball {
      name = "androidenv";
      url = "https://github.com/NixOS/nixpkgs/archive/<fill me in from Git>.tar.gz";
      sha256 = "<fill me in with nix-prefetch-url --unpack>";
    };

    androidEnv = pkgs.callPackage "${androidEnvNixpkgs}/pkgs/development/mobile/androidenv" {
      inherit config pkgs;
      licenseAccepted = true;
    };
  */

  # Otherwise, just use the in-tree androidenv:
  androidEnv = pkgs.callPackage ./.. {
    inherit config pkgs licenseAccepted;
  };

  sdkArgs = {
    includeSystemImages = true;
    includeEmulator = true;

    # Accepting more licenses declaratively:
    extraLicenses = [
      # Already accepted for you with the global accept_license = true or
      # licenseAccepted = true on androidenv.
      # "android-sdk-license"

      # These aren't, but are useful for more uncommon setups.
      "android-sdk-preview-license"
      "android-googletv-license"
      "android-sdk-arm-dbt-license"
      "google-gdk-license"
      "intel-android-extra-license"
      "intel-android-sysimage-license"
      "mips-android-sysimage-license"
    ];
  };

  androidComposition = androidEnv.composeAndroidPackages sdkArgs;
  androidEmulator = androidEnv.emulateApp {
    name = "android-sdk-emulator-demo";
    configOptions = {
      "hw.keyboard" = "yes";
    };
    sdkExtraArgs = sdkArgs;
  };
  androidSdk = androidComposition.androidsdk;
  platformTools = androidComposition.platform-tools;
  jdk = pkgs.jdk;
in
pkgs.mkShell rec {
  name = "androidenv-demo";
  packages = [
    androidSdk
    platformTools
    androidEmulator
    jdk
  ];

  LANG = "C.UTF-8";
  LC_ALL = "C.UTF-8";
  JAVA_HOME = jdk.home;

  # Note: ANDROID_HOME is deprecated. Use ANDROID_SDK_ROOT.
  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
  ANDROID_NDK_ROOT = "${ANDROID_SDK_ROOT}/ndk-bundle";

  shellHook = ''
    # Write out local.properties for Android Studio.
    cat <<EOF > local.properties
    # This file was automatically generated by nix-shell.
    sdk.dir=$ANDROID_SDK_ROOT
    ndk.dir=$ANDROID_NDK_ROOT
    EOF
  '';

  passthru.tests = {

    shell-with-emulator-sdkmanager-packages-test =
      pkgs.runCommand "shell-with-emulator-sdkmanager-packages-test"
        {
          nativeBuildInputs = [
            androidSdk
            jdk
          ];
        }
        ''
          output="$(sdkmanager --list)"
          installed_packages_section=$(echo "''${output%%Available Packages*}" | awk 'NR>4 {print $1}')
          echo "installed_packages_section: ''${installed_packages_section}"

          packages=(
            "build-tools" "cmdline-tools" \
            "emulator" "platform-tools" "platforms;android-35" \
            "system-images;android-35;google_apis;x86_64"
          )

          for package in "''${packages[@]}"; do
            if [[ ! $installed_packages_section =~ "$package" ]]; then
              echo "$package package was not installed."
              exit 1
            fi
          done

          touch "$out"
        '';

    shell-with-emulator-sdkmanager-excluded-packages-test =
      pkgs.runCommand "shell-with-emulator-sdkmanager-excluded-packages-test"
        {
          nativeBuildInputs = [
            androidSdk
            jdk
          ];
        }
        ''
          output="$(sdkmanager --list)"
          installed_packages_section=$(echo "''${output%%Available Packages*}" | awk 'NR>4 {print $1}')

          excluded_packages=(
            "platforms;android-23" "platforms;android-24" "platforms;android-25" "platforms;android-26" \
            "platforms;android-27" "platforms;android-28" "platforms;android-29" "platforms;android-30" \
            "platforms;android-31" "platforms;android-32" "platforms;android-33" "platforms;android-34" \
            "sources;android-23" "sources;android-24" "sources;android-25" "sources;android-26" \
            "sources;android-27" "sources;android-28" "sources;android-29" "sources;android-30" \
            "sources;android-31" "sources;android-32" "sources;android-33" "sources;android-34" \
            "system-images;android-28" \
            "system-images;android-29" \
            "system-images;android-30" \
            "system-images;android-31" \
            "system-images;android-32" \
            "system-images;android-33" \
            "ndk"
          )

          for package in "''${excluded_packages[@]}"; do
            if [[ $installed_packages_section =~ "$package" ]]; then
              echo "$package package was installed, while it was excluded!"
              exit 1
            fi
          done

          touch "$out"
        '';

    shell-with-emulator-avdmanager-create-avd-test =
      pkgs.runCommand "shell-with-emulator-avdmanager-create-avd-test"
        {
          nativeBuildInputs = [
            androidSdk
            androidEmulator
            jdk
          ];
        }
        ''
          export ANDROID_USER_HOME=$PWD/.android
          mkdir -p $ANDROID_USER_HOME

          avdmanager delete avd -n testAVD || true
          echo "" | avdmanager create avd --force --name testAVD --package 'system-images;android-35;google_apis;x86_64'
          result=$(avdmanager list avd)

          if [[ ! $result =~ "Name: testAVD" ]]; then
            echo "avdmanager couldn't create the avd! The output is :''${result}"
            exit 1
          fi

          avdmanager delete avd -n testAVD || true
          touch "$out"
        '';
  };
}
