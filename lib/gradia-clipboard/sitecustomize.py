import importlib.abc
import importlib.machinery
import os
import shutil
import subprocess
import sys
import tempfile


def _copy_pixbuf_with_gdk(module, pixbuf):
  display = module.Gdk.Display.get_default()
  if not display:
    print("Warning: Failed to retrieve `Gdk.Display` object.", file=sys.stderr)
    return False

  clipboard = display.get_clipboard()
  content_provider = module.Gdk.ContentProvider.new_for_value(pixbuf)
  return bool(clipboard.set_content(content_provider))


def _copy_pixbuf_with_wl_copy(module, pixbuf):
  wl_copy = os.environ.get("RYOKU_GRADIA_WL_COPY", "wl-copy")
  wl_copy_path = wl_copy if os.path.sep in wl_copy else shutil.which(wl_copy)

  if wl_copy_path:
    temp_path = ""
    try:
      fd, temp_path = tempfile.mkstemp(prefix="ryoku-gradia-copy-", suffix=".png")
      os.close(fd)
      pixbuf.savev(temp_path, "png", [], [])
      with open(temp_path, "rb") as image:
        subprocess.run(
          [wl_copy_path, "--type", "image/png"],
          stdin=image,
          stdout=subprocess.DEVNULL,
          stderr=subprocess.DEVNULL,
          check=True,
        )
      return True
    except Exception as error:
      print(f"ryoku-gradia: wl-copy image clipboard failed: {error}", file=sys.stderr)
    finally:
      if temp_path:
        try:
          os.unlink(temp_path)
        except FileNotFoundError:
          pass

  return _copy_pixbuf_with_gdk(module, pixbuf)


def _patch_clipboard_module(module):
  if getattr(module, "_ryoku_clipboard_patch", False):
    return

  module.copy_pixbuf_to_clipboard = lambda pixbuf: _copy_pixbuf_with_wl_copy(module, pixbuf)
  module._ryoku_clipboard_patch = True


class _GradiaClipboardPatchLoader(importlib.abc.Loader):
  def __init__(self, wrapped):
    self.wrapped = wrapped

  def create_module(self, spec):
    if hasattr(self.wrapped, "create_module"):
      return self.wrapped.create_module(spec)
    return None

  def exec_module(self, module):
    self.wrapped.exec_module(module)
    _patch_clipboard_module(module)


class _GradiaClipboardPatchFinder(importlib.abc.MetaPathFinder):
  def find_spec(self, fullname, path=None, target=None):
    if fullname != "gradia.clipboard":
      return None

    spec = importlib.machinery.PathFinder.find_spec(fullname, path)
    if spec and spec.loader:
      spec.loader = _GradiaClipboardPatchLoader(spec.loader)
    return spec


if "gradia.clipboard" in sys.modules:
  _patch_clipboard_module(sys.modules["gradia.clipboard"])
else:
  sys.meta_path.insert(0, _GradiaClipboardPatchFinder())
