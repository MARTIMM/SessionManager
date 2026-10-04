use v6.d;
use NativeCall;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Picture:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::T-textiter:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;
use Gnome::Gtk4::Widget:api<2>;
use Gnome::Gtk4::Frame:api<2>;

use Gnome::GdkPixbuf::Pixbuf:api<2>;

use Gnome::Gdk4::Texture:api<2>;

use Gnome::Glib::T-error:api<2>;

use Gnome::Pango::T-layout:api<2>;

use GnomeTools::Gtk::DropDown;

#-------------------------------------------------------------------------------
unit module SessionManager::Gui::EditTools;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Image = Gnome::Gtk4::Image;
constant Grid = Gnome::Gtk4::Grid;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
constant Widget = Gnome::Gtk4::Widget;
constant Picture = Gnome::Gtk4::Picture;
constant Frame = Gnome::Gtk4::Frame;

constant Pixbuf = Gnome::GdkPixbuf::Pixbuf;

constant Texture = Gnome::Gdk4::Texture;

constant DropDown = GnomeTools::Gtk::DropDown;

constant EDIT_WIDTH_CHARS = 80;

#-------------------------------------------------------------------------------
sub make-title ( Str:D $title --> Label ) is export {
  with my Label $l = make-label() {
    .set-use-markup(True);
    .set-markup('<span size="xx-large">' ~ $title ~ '</span>');
    .set-halign(GTK_ALIGN_FILL);
  }

  $l
}

#-------------------------------------------------------------------------------
sub make-horizontal-strut ( --> Label ) is export {
  with my Label $l = make-label() {
    .set-wrap(False);
    .set-halign(GTK_ALIGN_FILL);
    .set-hexpand(True);
    .set-text('');
  }

  $l
}

#-------------------------------------------------------------------------------
sub make-vertical-space ( --> Label ) is export {
  with my Label $l = make-label() {
    .set-wrap(False);
    .set-text(' ');
  }

  $l
}

#-------------------------------------------------------------------------------
sub make-vertical-strut ( --> Label ) is export {
  with my Label $l = make-label() {
    .set-wrap(False);
    .set-valign(GTK_ALIGN_FILL);
    .set-vexpand(True);
    .set-text('');
  }

  $l
}

#-------------------------------------------------------------------------------
sub make-label (
  Str :$label-text, Int :$width = EDIT_WIDTH_CHARS,
  Bool :$justify-left = True
  --> Label
) is export {
  with my Label $label .= new-label {
    .set-halign(GTK_ALIGN_START);
    .set-justify($justify-left ?? GTK_JUSTIFY_LEFT !! GTK_JUSTIFY_RIGHT);
#    .set-hexpand(True);
    .set-wrap(True);
    .set-wrap-mode(PANGO_WRAP_WORD);
    .set-max-width-chars($width);
    .set-text($label-text) if ?$label-text;
  }

  $label
}

#-------------------------------------------------------------------------------
sub make-entry ( --> Entry ) is export {
  with my Entry $entry .= new-entry {
    .set-halign(GTK_ALIGN_FILL);
    .set-hexpand(True);
#    .set-wrap(True);
#    .set-wrap-mode(PANGO_WRAP_WORD);
#    .set-max-width-chars(EDIT_WIDTH-CHARS);
  }

  $entry
}

#-------------------------------------------------------------------------------
# Used to make small icons like led images
sub make-image ( --> Image ) is export {
  with my Image $image .= new-image {
    .set-size-request( 40, 40);
    .set-margin-end(5);
  }

  $image
}

#-------------------------------------------------------------------------------
# Used to make larger images used for the session and action buttons
sub make-picture-frame ( --> Frame ) is export {
  with my Frame $frame .= new-frame {
    .set-margin-start(5);
    .set-child(Picture.new-picture);
  }

  $frame
}

#-------------------------------------------------------------------------------
sub set-picture-in-frame (
  Str $filename, Frame $frame, Int :$w = 200, Int :$h = 200
  --> Str
) is export {
  my Picture() $picture = $frame.get-child;
  my Str $message;
  my $e = CArray[N-Error].new(N-Error);
  my Pixbuf $pixbuf .= new-from-file-at-size( $filename, $w, $h, $e);
  if $e[0].defined {
    $message = $e[0].message;
  } else {
    my Texture $texture .= new-for-pixbuf($pixbuf);
    $picture.set-paintable($texture);
    $picture.set-size-request( $w, $h);
    $texture.clear-object;
  }
  
  $message
}

#-------------------------------------------------------------------------------
sub set-text-at (
  Int $row, Int $col, Str $text, Grid $grid
) is export {
  my Label() $label = $grid.get-child-at( $row, $col);
  $label.set-text($text);
}

#-------------------------------------------------------------------------------
sub set-image-at (
  Int $row, Int $col, Str $color, Bool $name-inuse, Grid $grid
) is export {
  my Str $on-off = $name-inuse ?? 'on' !! 'off';
  my Image() $used = $grid.get-child-at( $row, $col);
  my Str $resource = $color ~ '-' ~ $on-off ~ '-256.png';
  $used.set-from-file(%?RESOURCES{$resource});
}

#-------------------------------------------------------------------------------
sub get-textview-text ( TextView:D $textview --> Str ) is export {
  my TextBuffer() $tb = $textview.get-buffer;
  my N-TextIter $t0 .= new;
  my N-TextIter $te .= new;
  $tb.get-bounds( $t0, $te);

  $tb.get-text( $t0, $te, False)
}

#-------------------------------------------------------------------------------
sub refill-dropdown ( DropDown $dd, @values ) is export {
  $dd.remove(| ^$dd.get-n-items);
  $dd.append(@values);
}

#-------------------------------------------------------------------------------
our $add-content1 = multi sub add-content (
  Grid $grid, Int $row, Str $label-text, *@widgets, *%options
) is export {
  my Label $l = make-label;
  $l.set-text($label-text);
  add-content( $grid, $row, $l, |@widgets, |%options);
}

#-------------------------------------------------------------------------------
our $add-content2 = multi sub add-content (
  Grid $grid, Int $row, Widget $w, *@widgets,
  Int :$columns = 1, Int :$rows = 1
) is export {

  my Int $column = 0;
  $grid.attach( $w, $column++, $row, 1, 1);

  my Int $c = $columns;
  for @widgets -> $widget {
    if $widget ~~ Int {
      $c = $widget;
      next;
    }

    $widget.set-hexpand(True);
    $grid.attach( $widget, $column, $row, $c, $rows);
    $column += $columns;
    
    $c = $columns;
  }
}

