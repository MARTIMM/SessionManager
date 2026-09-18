use v6.d;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use SessionManager::Gui::EditTools;

#use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListBox;
use GnomeTools::Gtk::ListView;
use GnomeTools::Gtk::Statusbar;

use Gnome::Gtk4::TextView:api<2>;
use Gnome::Gtk4::TextBuffer:api<2>;
use Gnome::Gtk4::T-textiter:api<2>;
use Gnome::Gtk4::ScrolledWindow:api<2>;
use Gnome::Gtk4::Switch:api<2>;
use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Box:api<2>;
use Gnome::Gtk4::Widget:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use Gnome::Pango::T-layout:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditActionGrid;
also is Gnome::Gtk4::Grid;


constant ListBox = GnomeTools::Gtk::ListBox;
constant ListView = GnomeTools::Gtk::ListView;
#constant Dialog = GnomeTools::Gtk::Dialog;
constant Statusbar = GnomeTools::Gtk::Statusbar;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Switch = Gnome::Gtk4::Switch;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;
constant ScrolledWindow = Gnome::Gtk4::ScrolledWindow;
constant TextView = Gnome::Gtk4::TextView;
constant TextBuffer = Gnome::Gtk4::TextBuffer;
constant Widget = Gnome::Gtk4::Widget;

constant EDIT_WIDTH = 500;
constant EDIT_HEIGHT = 1000;
constant EDIT_WIDTH-CHARS = 80;


has Hash $!data-ids;
#has Str $!id-to-return-from-dialog = '';

has SessionManager::Actions $!actions;
has SessionManager::Sessions $!sessions;
has SessionManager::Variables $!variables;

has Statusbar $!statusbar;

has ListView $!actions-view;

has Entry $!action-id;
has Entry $!aspec-title;
has Entry $!aspec-path;
has Entry $!aspec-icon;
has Entry $!aspec-pic;

has Label $!aspec-title-subst;
has Label $!aspec-path-subst;
has Label $!aspec-icon-subst;
has Label $!aspec-pic-subst;
has Label $!aspec-cmd-subst;

has TextView $!aspec-cmd;
has Entry $!aspec-shell;
has Entry $!aspec-wait;
has Switch $!aspec-log;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditActionGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  my SessionManager::Config $config .= instance;
  $config.theme.add-css-class( self, 'edit-grid');

  $!data-ids = %();
  $!sessions .= new;
  $!actions .= new;
  $!variables .= new;

  with self {
    self.init-fields;

    my Int $row = 0;
    with my Label $title = make-label() {
      .set-use-markup(True);
      .set-markup(Q[<span size="xx-large">Actions</span>]);
      .set-halign(GTK_ALIGN_FILL);
    }
    .attach( $title, 0, $row++, 1, 1);
    my Label $vstrut1 = make-label();
    $vstrut1.set-text(' ');
    .attach( $vstrut1, 0, $row++, 1, 1);

    .attach( self!dialog-grid, 0, $row++, 1, 1);
#`{{

    $!statusbar .= new;
    .attach( $!statusbar, 0, $row++, 1, 1);

   .attach( self!button-row, 0, $row++, 1, 1);

    my Label $vstrut2 = make-label();
    $vstrut2.set-text(' ');
    .attach( $vstrut2, 0, $row++, 1, 1);
  }}
#    $!variables-view = self!list-view;
#    .attach( $!variables-view,  0, $row++, 1, 1);
  }
}

#-------------------------------------------------------------------------------
method init-fields ( Bool :$id-is-sensitive = True, :$id-only = False ) {

  with $!action-id .= new-entry {
    .set-sensitive($id-is-sensitive);
    .set-placeholder-text('unique action id');
    .set-size-request( 600, -1);
  }

  with $!aspec-title .= new-entry {
    .set-sensitive(!$id-only);
    .set-placeholder-text('description of this action');
  }

  with $!aspec-title-subst .= new-label {
    .set-halign(GTK_ALIGN_START);
#    .set-size-request( 600, -1);
  }

  with $!aspec-icon .= new-entry {
    .set-placeholder-text('optional small picture of application');
    .set-sensitive(!$id-only);
  }

  with $!aspec-icon-subst .= new-label {
    .set-halign(GTK_ALIGN_START);
  }

  with $!aspec-pic .= new-entry {
    .set-placeholder-text('optional picture of application');
    .set-sensitive(!$id-only);
  }

  with $!aspec-pic-subst .= new-label {
    .set-halign(GTK_ALIGN_START);
  }

  with $!aspec-path .= new-entry {
    .set-placeholder-text('optional path to start in');
    .set-sensitive(!$id-only);
  }

  with $!aspec-path-subst .= new-label {
    .set-halign(GTK_ALIGN_START);
  }

  with $!aspec-cmd .= new-textview {
    .set-size-request( -1, 100);
    .set-sensitive(!$id-only);
  }

  with $!aspec-cmd-subst .= new-label {
    .set-halign(GTK_ALIGN_START);
#    .set-wrap(True);
  }

  with $!aspec-shell .= new-entry {
    .set-sensitive(!$id-only);
  }

  with $!aspec-wait .= new-entry {
    .set-placeholder-text('optional');
    .set-sensitive(!$id-only);
  }

  with $!aspec-log .= new-switch {
    .set-sensitive(!$id-only);
    .set-size-request( 80, -1);
  }

#TODO add fields for variables and environment
#  $!aspec-env .= new-textview;
#  $!aspec-env.set-size-request( -1, 100);
#  $!aspec-temp-vars .= new-textview;
#  $!aspec-temp-vars.set-size-request( -1, 100);

  with $!actions-view .= new(:!multi-select) {
    .set-size-request( -1, 500);

    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'set-input-fields');

    .append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
#    .append($!actions.get-action-idss[^2]);

    # Select the first one
    .set-selection(0);
  }
}

#-------------------------------------------------------------------------------
method setup-item ( --> Widget ) {
  my Label $action-id = make-label();
  my Label $action-value = make-label();
  my Image $used = make-image();

  with my Grid $grid .= new-grid {
    .attach( $used, 0, 0, 2, 2);
    .attach( $action-id, 2, 0, 1, 1);
    .attach( $action-value, 2, 1, 1, 1);
  }

  $grid;
}

#-------------------------------------------------------------------------------
method bind-item ( Grid() $grid, Str $name ) {
#note $?LINE;
  my Hash $action-object = $!actions.get-raw-action($name);
  set-text-at( 2, 0, $name, $grid);
  set-text-at( 2, 1, $action-object<t>//'', $grid);

  my Bool $name-inuse = self.check-action-inuse($name);
  set-image-at( 0, 0, 'green', $name, $name-inuse, $grid);
}

#-------------------------------------------------------------------------------
method check-action-inuse ( Str:D $name --> Bool ) {
  # Check if action is used in the sessions store
  $!sessions.is-action-in-use($name);
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( Grid() $grid ) {
  $grid.clear-object;
}

#-------------------------------------------------------------------------------
method !dialog-grid ( --> Grid ) {

  my Int $row = 0;
  my Grid $dialog-grid .= new-grid;
#  with self {
    add-content( $row++, $dialog-grid, 'Current actions', $!actions-view);

    my Entry $search .= new-entry;
    $search.set-size-request( 250, -1);
    with my Button $search-button .= new-button {
      .set-label('Select from list');
      .register-signal( self, 'select-from-list', 'clicked', :$search);
    }
    with my Button $reset-button .= new-button {
      .set-label('Reset search');
      .register-signal( self, 'reset-list', 'clicked', :$search);
    }
    my Box $bt-box .= new-box( GTK_ORIENTATION_HORIZONTAL, 10);
    $bt-box.append($search-button);
    $bt-box.append($reset-button);
    my Label $strut1 .= new-label;
    $bt-box.append($strut1);
    add-content( $row++, $dialog-grid, 'Search in list', $search, $bt-box);

    add-content( $row++, $dialog-grid, 'Action id', $!action-id);
    add-content( $row++, $dialog-grid, 'Action Title', $!aspec-title, $!aspec-title-subst);
    add-content( $row++, $dialog-grid, 'Command to run', $!aspec-cmd, $!aspec-cmd-subst);
    add-content( $row++, $dialog-grid, 'Shell to work in', $!aspec-shell);
    add-content( $row++, $dialog-grid, 'Path to start in', $!aspec-path, $!aspec-path-subst);
    add-content( $row++, $dialog-grid, 'Icon', $!aspec-icon, $!aspec-icon-subst);
    add-content( $row++, $dialog-grid, 'Picture', $!aspec-pic, $!aspec-pic-subst);
    add-content( $row++, $dialog-grid, 'Wait before log window closes', $!aspec-wait);

    my Box $sw-box .= new-box( GTK_ORIENTATION_HORIZONTAL, 0);
    $sw-box.append($!aspec-log);
    my Label $strut2 .= new-label;
    $sw-box.append($strut2);
    add-content( $row++, $dialog-grid, 'Turn logging on', $sw-box);
    add-content( $row++, $dialog-grid, 'Turn logging on', $!aspec-wait);
#  }
  
  $dialog-grid
}

#-------------------------------------------------------------------------------
method !button-row ( ) {

}

#-------------------------------------------------------------------------------
method select-from-list ( Entry :$search ) {
  my Str $search-text = $search.get-text;
  my @actions = $!actions.get-action-ids.sort: {$^a.lc leg $^b.lc};
  $!actions-view.remove(0..^@actions.elems);
  for @actions -> $item {
    $!actions-view.append($item) if $item ~~ m/ $search-text /;
  }
}

#-------------------------------------------------------------------------------
method reset-list ( Entry :$search ) {
  $!actions-view.remove(^$!actions-view.get-n-items);
  $!actions-view.append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
  $search.set-text('');
}

#-------------------------------------------------------------------------------
method set-input-fields ( UInt $pos, @selections,
  Str :id($old-id), Widget :$action-id,
  Entry :$aspec-title, TextView :$aspec-cmd, Entry :$aspec-path,
  Entry :$aspec-wait, Switch :$aspec-log, Entry :$aspec-icon,
  Entry :$aspec-pic, Entry :$aspec-shell
) {
#TODO show tooltip over fields with filled in variables
#  $!actions .= new;
  my $id = @selections[0];
  my Hash $action-object = $!actions.get-raw-action($id);

  $!action-id.set-text($id);

  my Str $t = $action-object<t> // '';
  $!aspec-title.set-text($t);
  $!aspec-title-subst.set-text($!variables.substitute-vars($t));

  with $!aspec-cmd {
    my TextBuffer() $tb = .get-buffer;
    if ? my $s = $action-object<c> {
      $tb.set-text( $s, $s.chars);
      $!aspec-cmd-subst.set-text($!variables.substitute-vars($s));
    }

    else {
      $tb.set-text( '', 0);
      $!aspec-cmd-subst.set-text($!variables.substitute-vars(''));
    }
  }


  $t = $action-object<p> // '';
  $!aspec-path.set-text($t);
  $!aspec-path-subst.set-text($!variables.substitute-vars($t));

  with $!aspec-wait { .set-text($action-object<w> // ''); }
  with $!aspec-log { .set-state($action-object<l>.Bool); }

  $t = $action-object<o> // '';
  $!aspec-icon.set-text($t);
  $!aspec-icon-subst.set-text($!variables.substitute-vars($t));

  $t = $action-object<i> // '';
  $!aspec-pic.set-text($t);
  $!aspec-pic-subst.set-text($!variables.substitute-vars($t));

  with $!aspec-shell { .set-placeholder-text($action-object<sh>); }
}

#-------------------------------------------------------------------------------
method selection-changed ( UInt $pos, @selections ) {
}


=finish
#TODO must refactor
#-------------------------------------------------------------------------------
method make-label ( --> Label ) {
  with my Label $label .= new-label {
    .set-halign(GTK_ALIGN_START);
    .set-justify(GTK_JUSTIFY_LEFT);
    .set-hexpand(True);
    .set-wrap(True);
    .set-wrap-mode(PANGO_WRAP_WORD);
    .set-max-width-chars(EDIT_WIDTH-CHARS);
  }

  $label
}

#-------------------------------------------------------------------------------
method make-entry ( --> Entry ) {
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
method make-image ( --> Image ) {
  with my Image $image .= new-image {
    .set-size-request( 40, 40);
    .set-margin-end(10);
  }

  $image
}

#-------------------------------------------------------------------------------
method set-text-at ( Int $row, Int $col, Str $text, Gnome::Gtk4::Grid $grid ) {
  my Label() $label = $grid.get-child-at( $row, $col);
  $label.set-text($text);
}

#-------------------------------------------------------------------------------
method set-image-at (
  Int $row, Int $col, Str $color, Str $name,
  Bool $name-inuse, Gnome::Gtk4::Grid $grid
) {
  my Str $on-off = $name-inuse ?? 'on' !! 'off';
  my Image() $used = $grid.get-child-at( $row, $col);
  my Str $resource = $color ~ '-' ~ $on-off ~ '-256.png';
  $used.set-from-file(%?RESOURCES{$resource});
}
