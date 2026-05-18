About
=====

Jumpcut is a clipboard manager for macOS, providing access to text that
you've cut or copied, even if you've subsequently cut or copied something
else.

Jumpcut has a lightweight, intuitive interface and is 100% focused on
your clipboard, keeping code snippets, email addresses, URLs, and that
sentence that you actually had _just right_ five minutes ago close to hand.

This fork adds a few larger-workflow conveniences. They are off by default;
enable **Hotkey > Enable extended clipping actions and 500-item history** in
Preferences to use them.

* The clipping history can remember up to 500 items.
* Individual clippings can be marked as favourites from the alternate clipping
  menu. Favourites are marked with `[F]` and are available from a dedicated
  Favourites submenu.
* Clippings can be visually labelled from the alternate clipping menu with
  bold, italic, and a small color palette. These labels are visible in the main
  clipping menu, the alternate menu, and the Favourites submenu.
* Clippings can be saved to disk: save a selected clipping to a file, save all
  clippings into one text file, or save all clippings as separate text files.

After enabling extended clipping actions, add a clipping to favourites by
opening Jumpcut's alternate clipping menu (for example, right-click or
Shift-click the menu bar icon, depending on your preferences), hovering the
clipping, and choosing **Add to Favourites**.

For menu clicks to paste directly into another app, macOS must allow Jumpcut
under **System Settings > Privacy & Security > Accessibility**. If selecting a
clipping updates the pasteboard but does not paste into the editor, enable
Jumpcut in Accessibility and restart Jumpcut. Without that permission Jumpcut
can still copy the clipping to the pasteboard, but macOS blocks the synthetic
Command-V event used for paste.

I made these changes for my own benefit and have sent a PR. They are most
likely not useful to others and they kind of violate the minimalism of Jumpcut,
but hey - works for me.
