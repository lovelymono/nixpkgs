{
  stdenv,
  lib,
  fetchurl,
  fetchFromGitHub,
  fetchpatch,
  fixDarwinDylibNames,
  autoconf,
  aws-sdk-cpp,
  aws-sdk-cpp-arrow ? aws-sdk-cpp.override {
    apis = [
      "cognito-identity"
      "config"
      "identity-management"
      "s3"
      "sts"
      "transfer"
    ];
  },
  boost,
  brotli,
  bzip2,
  cmake,
  crc32c,
  curl,
  flatbuffers,
  gflags,
  glog,
  google-cloud-cpp,
  grpc,
  gtest,
  libbacktrace,
  lz4,
  minio,
  ninja,
  nlohmann_json,
  openssl,
  perl,
  pkg-config,
  protobuf,
  python3,
  rapidjson,
  re2,
  snappy,
  sqlite,
  thrift,
  tzdata,
  utf8proc,
  which,
  zlib,
  zstd,
  testers,
  enableShared ? !stdenv.hostPlatform.isStatic,
  enableFlight ? stdenv.buildPlatform == stdenv.hostPlatform,
  enableJemalloc ? !stdenv.hostPlatform.isDarwin && !stdenv.hostPlatform.isAarch64,
  enableS3 ? true,
  enableGcs ? !stdenv.hostPlatform.isDarwin,
}:

assert lib.asserts.assertMsg (
  (enableS3 && stdenv.hostPlatform.isDarwin)
  -> (lib.versionOlder boost.version "1.69" || lib.versionAtLeast boost.version "1.70")
) "S3 on Darwin requires Boost != 1.69";

let
  arrow-testing = fetchFromGitHub {
    name = "arrow-testing";
    owner = "apache";
    repo = "arrow-testing";
    rev = "4d209492d514c2d3cb2d392681b9aa00e6d8da1c";
    hash = "sha256-IkiCbuy0bWyClPZ4ZEdkEP7jFYLhM7RCuNLd6Lazd4o=";
  };

  parquet-testing = fetchFromGitHub {
    name = "parquet-testing";
    owner = "apache";
    repo = "parquet-testing";
    rev = "a7f1d288e693dbb08e3199851c4eb2140ff8dff2";
    hash = "sha256-zLWJOWcW7OYL32OwBm9VFtHbmG+ibhteRfHlKr9G3CQ=";
  };

  version = "18.1.0";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "arrow-cpp";
  inherit version;

  src = fetchFromGitHub {
    owner = "apache";
    repo = "arrow";
    rev = "apache-arrow-${version}";
    hash = "sha256-Jo3be5bVuDaDcSbW3pS8y9Wc2sz1W2tS6QTwf0XpODA";
  };

  sourceRoot = "${finalAttrs.src.name}/cpp";

  patches = [
    # fixes build with libcxx-19 (llvm-19) remove on update
    (fetchpatch {
      name = "libcxx-19-fixes.patch";
      url = "https://github.com/apache/arrow/commit/29e8ea011045ba4318a552567a26b2bb0a7d3f05.patch";
      relative = "cpp";
      includes = [ "src/arrow/buffer_test.cc" ];
      hash = "sha256-ZHkznOilypi1J22d56PhLlw/hbz8RqwsOGDMqI1NsMs=";
    })
    # https://github.com/apache/arrow/pull/45057 remove on update
    (fetchpatch {
      name = "boost-187.patch";
      url = "https://github.com/apache/arrow/commit/5ec8b64668896ff06a86b6a41e700145324e1e34.patch";
      relative = "cpp";
      hash = "sha256-GkB7u4YnnaCApOMQPYFJuLdY7R2LtLzKccMEpKCO9ic=";
    })
  ];

  # versions are all taken from
  # https://github.com/apache/arrow/blob/apache-arrow-${version}/cpp/thirdparty/versions.txt

  # jemalloc: arrow uses a custom prefix to prevent default allocator symbol
  # collisions as well as custom build flags
  ${if enableJemalloc then "ARROW_JEMALLOC_URL" else null} = fetchurl {
    url = "https://github.com/jemalloc/jemalloc/releases/download/5.3.0/jemalloc-5.3.0.tar.bz2";
    hash = "sha256-LbgtHnEZ3z5xt2QCGbbf6EeJvAU3mDw7esT3GJrs/qo=";
  };

  # mimalloc: arrow uses custom build flags for mimalloc
  ARROW_MIMALLOC_URL = fetchFromGitHub {
    owner = "microsoft";
    repo = "mimalloc";
    rev = "v2.0.6";
    hash = "sha256-u2ITXABBN/dwU+mCIbL3tN1f4c17aBuSdNTV+Adtohc=";
  };

  ARROW_XSIMD_URL = fetchFromGitHub {
    owner = "xtensor-stack";
    repo = "xsimd";
    rev = "13.0.0";
    hash = "sha256-qElJYW5QDj3s59L3NgZj5zkhnUMzIP2mBa1sPks3/CE=";
  };

  ARROW_SUBSTRAIT_URL = fetchFromGitHub {
    owner = "substrait-io";
    repo = "substrait";
    rev = "v0.44.0";
    hash = "sha256-V739IFTGPtbGPlxcOi8sAaYSDhNUEpITvN9IqdPReug=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    ninja
    autoconf # for vendored jemalloc
    flatbuffers
  ] ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames;
  buildInputs =
    [
      boost
      brotli
      bzip2
      flatbuffers
      gflags
      glog
      gtest
      libbacktrace
      lz4
      nlohmann_json # alternative JSON parser to rapidjson
      protobuf # substrait requires protobuf
      rapidjson
      re2
      snappy
      thrift
      utf8proc
      zlib
      zstd
    ]
    ++ lib.optionals enableFlight [
      grpc
      openssl
      protobuf
      sqlite
    ]
    ++ lib.optionals enableS3 [
      aws-sdk-cpp-arrow
      openssl
    ]
    ++ lib.optionals enableGcs [
      crc32c
      curl
      google-cloud-cpp
      grpc
      nlohmann_json
    ];

  preConfigure = ''
    patchShebangs build-support/
    substituteInPlace "src/arrow/vendored/datetime/tz.cpp" \
      --replace-fail 'discover_tz_dir();' '"${tzdata}/share/zoneinfo";'
  '';

  cmakeFlags =
    [
      "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON"
      "-DARROW_BUILD_SHARED=${if enableShared then "ON" else "OFF"}"
      "-DARROW_BUILD_STATIC=${if enableShared then "OFF" else "ON"}"
      "-DARROW_BUILD_TESTS=${if enableShared then "ON" else "OFF"}"
      "-DARROW_BUILD_INTEGRATION=ON"
      "-DARROW_BUILD_UTILITIES=ON"
      "-DARROW_EXTRA_ERROR_CONTEXT=ON"
      "-DARROW_VERBOSE_THIRDPARTY_BUILD=ON"
      "-DARROW_DEPENDENCY_SOURCE=SYSTEM"
      "-Dxsimd_SOURCE=AUTO"
      "-DARROW_DEPENDENCY_USE_SHARED=${if enableShared then "ON" else "OFF"}"
      "-DARROW_COMPUTE=ON"
      "-DARROW_CSV=ON"
      "-DARROW_DATASET=ON"
      "-DARROW_FILESYSTEM=ON"
      "-DARROW_FLIGHT_SQL=${if enableFlight then "ON" else "OFF"}"
      "-DARROW_HDFS=ON"
      "-DARROW_IPC=ON"
      "-DARROW_JEMALLOC=${if enableJemalloc then "ON" else "OFF"}"
      "-DARROW_JSON=ON"
      "-DARROW_USE_GLOG=ON"
      "-DARROW_WITH_BACKTRACE=ON"
      "-DARROW_WITH_BROTLI=ON"
      "-DARROW_WITH_BZ2=ON"
      "-DARROW_WITH_LZ4=ON"
      "-DARROW_WITH_NLOHMANN_JSON=ON"
      "-DARROW_WITH_SNAPPY=ON"
      "-DARROW_WITH_UTF8PROC=ON"
      "-DARROW_WITH_ZLIB=ON"
      "-DARROW_WITH_ZSTD=ON"
      "-DARROW_MIMALLOC=ON"
      "-DARROW_SUBSTRAIT=ON"
      "-DARROW_FLIGHT=${if enableFlight then "ON" else "OFF"}"
      "-DARROW_FLIGHT_TESTING=${if enableFlight then "ON" else "OFF"}"
      "-DARROW_S3=${if enableS3 then "ON" else "OFF"}"
      "-DARROW_GCS=${if enableGcs then "ON" else "OFF"}"
      # Parquet options:
      "-DARROW_PARQUET=ON"
      "-DPARQUET_BUILD_EXECUTABLES=ON"
      "-DPARQUET_REQUIRE_ENCRYPTION=ON"
    ]
    ++ lib.optionals (!enableShared) [ "-DARROW_TEST_LINKAGE=static" ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [
      "-DCMAKE_INSTALL_RPATH=@loader_path/../lib" # needed for tools executables
    ]
    ++ lib.optionals (!stdenv.hostPlatform.isx86_64) [ "-DARROW_USE_SIMD=OFF" ]
    ++ lib.optionals enableS3 [
      "-DAWSSDK_CORE_HEADER_FILE=${aws-sdk-cpp-arrow}/include/aws/core/Aws.h"
    ];

  doInstallCheck = true;
  ARROW_TEST_DATA = lib.optionalString finalAttrs.doInstallCheck "${arrow-testing}/data";
  PARQUET_TEST_DATA = lib.optionalString finalAttrs.doInstallCheck "${parquet-testing}/data";
  GTEST_FILTER =
    let
      # Upstream Issue: https://issues.apache.org/jira/browse/ARROW-11398
      filteredTests =
        lib.optionals stdenv.hostPlatform.isAarch64 [
          "TestFilterKernelWithNumeric/3.CompareArrayAndFilterRandomNumeric"
          "TestFilterKernelWithNumeric/7.CompareArrayAndFilterRandomNumeric"
          "TestCompareKernel.PrimitiveRandomTests"
        ]
        ++ lib.optionals enableS3 [
          "S3OptionsTest.FromUri"
          "S3RegionResolutionTest.NonExistentBucket"
          "S3RegionResolutionTest.PublicBucket"
          "S3RegionResolutionTest.RestrictedBucket"
          "TestMinioServer.Connect"
          "TestS3FS.*"
          "TestS3FSGeneric.*"
        ]
        ++ lib.optionals stdenv.hostPlatform.isDarwin [
          # TODO: revisit at 12.0.0 or when
          # https://github.com/apache/arrow/commit/295c6644ca6b67c95a662410b2c7faea0920c989
          # is available, see
          # https://github.com/apache/arrow/pull/15288#discussion_r1071244661
          "ExecPlanExecution.StressSourceSinkStopped"
        ];
    in
    lib.optionalString finalAttrs.doInstallCheck "-${lib.concatStringsSep ":" filteredTests}";

  __darwinAllowLocalNetworking = true;

  nativeInstallCheckInputs =
    [
      perl
      which
      sqlite
    ]
    ++ lib.optionals enableS3 [ minio ]
    ++ lib.optionals enableFlight [ python3 ];

  installCheckPhase =
    let
      disabledTests = [
        # flaky
        "arrow-flight-test"
        # requires networking
        "arrow-gcsfs-test"
        "arrow-flight-integration-test"
      ];
    in
    ''
      runHook preInstallCheck

      ctest -L unittest --exclude-regex '^(${lib.concatStringsSep "|" disabledTests})$'

      runHook postInstallCheck
    '';

  meta = with lib; {
    description = "Cross-language development platform for in-memory data";
    homepage = "https://arrow.apache.org/docs/cpp/";
    license = licenses.asl20;
    platforms = platforms.unix;
    maintainers = with maintainers; [
      tobim
      veprbl
      cpcloud
    ];
    pkgConfigModules = [
      "arrow"
      "arrow-acero"
      "arrow-compute"
      "arrow-csv"
      "arrow-dataset"
      "arrow-filesystem"
      "arrow-flight"
      "arrow-flight-sql"
      "arrow-flight-testing"
      "arrow-json"
      "arrow-substrait"
      "arrow-testing"
      "parquet"
    ];
  };
  passthru = {
    inherit
      enableFlight
      enableJemalloc
      enableS3
      enableGcs
      ;
    tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  };
})
