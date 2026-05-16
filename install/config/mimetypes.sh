ryoku-refresh-applications
update-desktop-database ~/.local/share/applications

# Open directories in file manager
xdg-mime default org.gnome.Nautilus.desktop inode/directory

# Open all images with imv
xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

# Open PDFs with the Document Viewer
xdg-mime default org.gnome.Evince.desktop application/pdf

# Use Helium as the default browser
xdg-settings set default-web-browser helium.desktop
xdg-mime default helium.desktop x-scheme-handler/http
xdg-mime default helium.desktop x-scheme-handler/https

# Open video files with mpv
xdg-mime default mpv.desktop video/mp4
xdg-mime default mpv.desktop video/x-msvideo
xdg-mime default mpv.desktop video/x-matroska
xdg-mime default mpv.desktop video/x-flv
xdg-mime default mpv.desktop video/x-ms-wmv
xdg-mime default mpv.desktop video/mpeg
xdg-mime default mpv.desktop video/ogg
xdg-mime default mpv.desktop video/webm
xdg-mime default mpv.desktop video/quicktime
xdg-mime default mpv.desktop video/3gpp
xdg-mime default mpv.desktop video/3gpp2
xdg-mime default mpv.desktop video/x-ms-asf
xdg-mime default mpv.desktop video/x-ogm+ogg
xdg-mime default mpv.desktop video/x-theora+ogg
xdg-mime default mpv.desktop application/ogg

# Use Helium for mailto: links unless the user installs a dedicated mail app.
xdg-mime default helium.desktop x-scheme-handler/mailto

# Open text files with Neovim through Ryoku's terminal-aware launcher.
xdg-mime default ryoku-editor.desktop text/plain
xdg-mime default ryoku-editor.desktop text/english
xdg-mime default ryoku-editor.desktop text/x-makefile
xdg-mime default ryoku-editor.desktop text/x-c++hdr
xdg-mime default ryoku-editor.desktop text/x-c++src
xdg-mime default ryoku-editor.desktop text/x-chdr
xdg-mime default ryoku-editor.desktop text/x-csrc
xdg-mime default ryoku-editor.desktop text/x-java
xdg-mime default ryoku-editor.desktop text/x-moc
xdg-mime default ryoku-editor.desktop text/x-pascal
xdg-mime default ryoku-editor.desktop text/x-tcl
xdg-mime default ryoku-editor.desktop text/x-tex
xdg-mime default ryoku-editor.desktop application/x-shellscript
xdg-mime default ryoku-editor.desktop text/x-c
xdg-mime default ryoku-editor.desktop text/x-c++
xdg-mime default ryoku-editor.desktop application/xml
xdg-mime default ryoku-editor.desktop text/xml
