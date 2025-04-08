use v6.d;

use Desktop::Dispatcher::ActionData;
use Desktop::Dispatcher::Actions;
use Desktop::Dispatcher::Command;
use Desktop::Dispatcher::Config;

#use Gnome::Gtk4::ApplicationWindow:api<2>;
#use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Button:api<2>;
#use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Picture:api<2>;
#use Gnome::Gtk4::Grid:api<2>;
#use Gnome::Gtk4::Frame:api<2>;
#use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Overlay:api<2>;
#use Gnome::Gtk4::PopoverMenu:api<2>;
#use Gnome::Gtk4::ScrolledWindow:api<2>;

#use Gnome::GdkPixbuf::Pixbuf:api<2>;
#use Gnome::Gdk4::Texture:api<2>;

#use Gnome::Glib::N-Error:api<2>;
#use Gnome::Glib::T-error:api<2>;

use Gnome::N::N-Object:api<2>;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::ActionsOrig:auth<github:MARTIMM>;

#constant Box = Gnome::Gtk4::Box;
#constant Grid = Gnome::Gtk4::Grid;
#constant ApplicationWindow = Gnome::Gtk4::ApplicationWindow;
#constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant Button = Gnome::Gtk4::Button;
#constant Label = Gnome::Gtk4::Label;
constant Picture = Gnome::Gtk4::Picture;
#constant Frame = Gnome::Gtk4::Frame;
constant Overlay = Gnome::Gtk4::Overlay;

use Digest::SHA256::Native;

#-------------------------------------------------------------------------------
unit class Desktop::Dispatcher::CreateButtonCommand;
also is Desktop::Dispatcher::Command;

#-------------------------------------------------------------------------------
has Desktop::Dispatcher::ActionData $!action-data handles <
      running run-log run-error tap
      >;

#-------------------------------------------------------------------------------
submethod BUILD ( Str:D :$id ) {
  my Desktop::Dispatcher::Actions $actions .= instance;
  $!action-data = $actions.get-action($id);
  die "Failed to find an action with id '$id'" unless ?$!action-data;
}

#-------------------------------------------------------------------------------
method execute ( --> Overlay ) {
  my Overlay $overlay .= new-overlay;
  my Picture $overlay-pic;
  my Picture $picture;

  my Desktop::Dispatcher::Config $config .= instance(:$config-directory);
  with $picture .= new-picture {
    .set-filename($!action-data.picture);
    .set-size-request($config.get-icon-size);

    .set-margin-top(0);
    .set-margin-bottom(0);
    .set-margin-start(0);
    .set-margin-end(0);
  }

  with my Button $button .= new-button {
    $config.set-css( .get-style-context, 'session-button');
    .set-child($picture);
    .set-tooltip-text($!action-data.tooltip);
    .register-signal( $!action-data, 'run-action', 'clicked');
  }

  $overlay.set-child($button);

  if $action<overlay-picture-file>:exists and
    $action<overlay-picture-file>.IO.r
  {
    with my Picture $overlay-pic .= new-for-paintable(
      self.set-texture($action<overlay-picture-file>)
    ) {
      $overlay.add-overlay($overlay-pic);
      .set-halign(GTK_ALIGN_END);
      .set-valign(GTK_ALIGN_END);

      $!config.set-css( .get-style-context, 'overlay-pic');
    }
  }

  $overlay
}
