from __future__ import annotations

import os
import platform
import re
import subprocess
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Callable, ClassVar, Self, TypedDict, override


class NRError(Exception):
    "nixos-rebuild general error."

    def __init__(self, message: str):
        self.message = message

    @override
    def __str__(self) -> str:
        return f"error: {self.message}"


class Action(Enum):
    SWITCH = "switch"
    BOOT = "boot"
    TEST = "test"
    BUILD = "build"
    EDIT = "edit"
    REPL = "repl"
    DRY_BUILD = "dry-build"
    DRY_RUN = "dry-run"
    DRY_ACTIVATE = "dry-activate"
    BUILD_VM = "build-vm"
    BUILD_VM_WITH_BOOTLOADER = "build-vm-with-bootloader"
    LIST_GENERATIONS = "list-generations"

    @override
    def __str__(self) -> str:
        return self.value

    @staticmethod
    def values() -> list[str]:
        return [a.value for a in Action]


@dataclass(frozen=True)
class Flake:
    path: Path
    attr: str
    _re: ClassVar = re.compile(r"^(?P<path>[^\#]*)\#?(?P<attr>[^\#\"]*)$")

    @override
    def __str__(self) -> str:
        return f"{self.path}#{self.attr}"

    @classmethod
    def parse(
        cls,
        flake_str: str,
        hostname_fn: Callable[[], str | None] = lambda: None,
    ) -> Self:
        m = cls._re.match(flake_str)
        assert m is not None, f"got no matches for {flake_str}"
        attr = m.group("attr")
        nixos_attr = f"nixosConfigurations.{attr or hostname_fn() or "default"}"
        return cls(Path(m.group("path")), nixos_attr)

    @classmethod
    def from_arg(cls, flake_arg: Any, target_host: Ssh | None) -> Self | None:
        def get_hostname() -> str | None:
            if target_host:
                from .process import run_wrapper  # circumvent circular import

                try:
                    return run_wrapper(
                        ["uname", "-n"],
                        check=True,
                        capture_output=True,
                        allow_tty=False,
                        remote=target_host,
                    ).stdout.strip()
                except (AttributeError, subprocess.CalledProcessError):
                    return None
            else:
                return platform.node()

        match flake_arg:
            case str(s):
                return cls.parse(s, get_hostname)
            case True:
                return cls.parse(".", get_hostname)
            case False:
                return None
            case _:
                # Use /etc/nixos/flake.nix if it exists.
                default_path = Path("/etc/nixos/flake.nix")
                if default_path.exists():
                    # It can be a symlink to the actual flake.
                    if default_path.is_symlink():
                        default_path = default_path.readlink()
                    return cls.parse(str(default_path.parent), get_hostname)
                else:
                    return None


@dataclass(frozen=True)
class Generation:
    id: int
    timestamp: str  # we may want to have a proper timestamp type in future
    current: bool


# camelCase since this will be used as output for `--json` flag
class GenerationJson(TypedDict):
    generation: int
    date: str
    nixosVersion: str
    kernelVersion: str
    configurationRevision: str
    specialisations: list[str]
    current: bool


@dataclass(frozen=True)
class Profile:
    name: str
    path: Path

    @classmethod
    def from_name(cls, name: str = "system") -> Self:
        match name:
            case "system":
                return cls(name, Path("/nix/var/nix/profiles/system"))
            case _:
                path = Path("/nix/var/nix/profiles/system-profiles") / name
                path.parent.mkdir(mode=0o755, parents=True, exist_ok=True)
                return cls(name, path)


@dataclass(frozen=True)
class Ssh:
    host: str
    opts: list[str]
    tty: bool

    @classmethod
    def from_arg(cls, host: str | None, tty: bool | None, tmp_dir: Path) -> Self | None:
        if host:
            opts = os.getenv("NIX_SSHOPTS", "").split() + [
                "-o",
                "ControlMaster=auto",
                "-o",
                f"ControlPath={tmp_dir / "ssh-%n"}",
                "-o",
                "ControlPersist=60",
            ]
            return cls(host, opts, bool(tty))
        else:
            return None
