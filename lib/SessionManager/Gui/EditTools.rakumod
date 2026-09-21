use v6.d;

use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::T-textiter:api<2>;
use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;

use Gnome::Pango::T-layout:api<2>;

#-------------------------------------------------------------------------------
unit module SessionManager::Gui::EditTools;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Image = Gnome::Gtk4::Image;
constant Grid = Gnome::Gtk4::Grid;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;

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
    .set-text('');
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
sub make-image ( --> Image ) is export {
  with my Image $image .= new-image {
    .set-size-request( 40, 40);
    .set-margin-end(10);
  }

  $image
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
  Int $row, Int $col, Str $color, Str $name,
  Bool $name-inuse, Grid $grid
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
multi sub add-content (
  Int $row, Grid $grid, Str $label-text, *@widgets, *%options
) is export {
  my Label $l = make-label();
  $l.set-text($label-text);
  add-content( $row, $grid, $l, |@widgets, |%options);
}

#-------------------------------------------------------------------------------
multi sub add-content (
  Int $row, Grid $grid, Label $l, *@widgets,
  Int :$columns = 1, Int :$rows = 1
) is export {
#  my Label $name-label .= new-label;
#  $name-label.set-text('Variable name');

#  $grid.attach( $name-label, 0, 0, 1, 1);
#  my Label $l = make-label();
#  $l.set-text($label-text);
  my Int $column = 0;
  $grid.attach( $l, $column++, $row, 1, 1);
  my $col = 1;
  for @widgets -> $w {
    $grid.attach( $w, $col++, $row, 1, 1);
  }

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


=finish
method add-content (
  Str:D $text, *@widgets, Int :$columns = 1, Int :$rows = 1
) {
  my Int $column = 0;
  $!content.attach(
    self!make-content-label($text), $column++, $!content-count, 1, 1
  );
}
