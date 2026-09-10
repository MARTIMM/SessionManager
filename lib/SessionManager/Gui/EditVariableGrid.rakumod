use v6.d;

use SessionManager::Variables;
use SessionManager::Actions;
use SessionManager::Sessions;
use SessionManager::Config;

use GnomeTools::Gtk::Dialog;
use GnomeTools::Gtk::DropDown;
use GnomeTools::Gtk::ListView;
use GnomeTools::Gtk::Statusbar;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Entry:api<2>;
use Gnome::Gtk4::Image:api<2>;
use Gnome::Gtk4::Button:api<2>;
use Gnome::Gtk4::T-enums:api<2>;
use Gnome::Gtk4::Box:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;
use Gnome::N::N-Object:api<2>;

use Gnome::Pango::T-layout:api<2>;

#use YAMLish;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::EditVariableGrid;
also is Gnome::Gtk4::Grid;

#constant ConfigPath = '/Config/variables.yaml';

constant ListView = GnomeTools::Gtk::ListView;
constant Dialog = GnomeTools::Gtk::Dialog;
constant Statusbar = GnomeTools::Gtk::Statusbar;

constant Entry = Gnome::Gtk4::Entry;
constant Label = Gnome::Gtk4::Label;
constant Grid = Gnome::Gtk4::Grid;
constant Button = Gnome::Gtk4::Button;
constant Box = Gnome::Gtk4::Box;
constant Image = Gnome::Gtk4::Image;

constant EDIT_WIDTH = 500;
constant EDIT_HEIGHT = 1000;
constant EDIT_WIDTH-CHARS = 80;

#has SessionManager::Variables $!variables;
has ListView $!variables-view;
has Grid $!dialog-grid;
has Entry $!variable-name;
has Entry $!variable-spec;
has Statusbar $!statusbar;

#-------------------------------------------------------------------------------
submethod new ( |c --> SessionManager::Gui::EditVariableGrid ) {
  self.new-grid(|c);
}

#-------------------------------------------------------------------------------
submethod BUILD ( ) {

  # When the data is loaded, the $!variables does not have to be initialized
  # Just only when other methods need to be called there.
  #$!variables .= new;

  with self {
    my Int $row = 0;
    with my Label $title = self.make-label {
      .set-use-markup(True);
      .set-markup(Q[<span size="xx-large">Variables</span>]);
      .set-halign(GTK_ALIGN_FILL);
    }
    .attach( $title, 0, $row++, 1, 1);

    my Label $vstrut1 = self.make-label;
    $vstrut1.set-text(' ');
    .attach( $vstrut1, 0, $row++, 1, 1);

#    my Grid $v = self!dialog-grid;
    .attach( self!dialog-grid, 0, $row++, 1, 1);

    $!statusbar .= new;
    .attach( $!statusbar, 0, $row++, 1, 1);

#    my Box $button-row = self!button-row;
    .attach( self!button-row, 0, $row++, 1, 1);

    my Label $vstrut2 = self.make-label;
    $vstrut2.set-text(' ');
    .attach( $vstrut2, 0, $row++, 1, 1);

    $!variables-view = self!list-view;
    .attach( $!variables-view,  0, $row++, 1, 1);
  }
}

#-------------------------------------------------------------------------------
method !list-view ( --> ListView ) {
  with my ListView $variables-view .= new(:!multi-select) {
    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

    .set-selection-changed( self, 'selection-changed');
    my SessionManager::Variables $v .= new;
    .append($v.get-variables.sort: {$^a.lc leg $^b.lc});
#    .append($!variables.get-variables[^2]);

    # Select the first one
    .set-selection(0);
    .set-size-request( EDIT_WIDTH, EDIT_HEIGHT);
  }

  $variables-view
}

#-------------------------------------------------------------------------------
method !dialog-grid ( --> Grid ) {
  with my Grid $dialog-grid .= new-grid {
    with my Label $name-label .= new-label {
      .set-text('Variable name');
    }
    .attach( $name-label, 0, 0, 1, 1);
    $!variable-name = self.make-entry;
    .attach( $!variable-name, 1, 0, 1, 1);

    with my Label $spec-label .= new-label {
      .set-text('Specification');
    }
    .attach( $spec-label, 0, 1, 1, 1);
    $!variable-spec = self.make-entry;
    .attach( $!variable-spec, 1, 1, 1, 1);
  }

  $dialog-grid
}

#-------------------------------------------------------------------------------
method variable-add ( ) {
  $!statusbar.set-status('');
  my SessionManager::Variables $v .= new;

  my Str $variable = $!variable-name.get-text;
  if !$variable {
    $!statusbar.set-status("No variable name");
  }

  elsif ?$v.get-variable($variable) {
    $!statusbar.set-status("Name '$variable' already defined");
  }

  else {
    my Str $spec = $!variable-spec.get-text;
    $v.add-variable( $variable, $spec);
    $!statusbar.set-status("Variable '$variable' added with '$spec'");
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 0, $variable);
  }
}

#-------------------------------------------------------------------------------
method variable-rename ( ) {
  $!statusbar.set-status('');
  my SessionManager::Variables $v .= new;

  my Str $variable = $!variable-name.get-text;
  if !$variable {
    $!statusbar.set-status("No variable name");
  }

  elsif ?$v.get-variable($variable) {
    $!statusbar.set-status("Name '$variable' already defined");
  }

  else {
    # Change the entry in the listview, returns array of possible selections
    my Str $original-name = $!variables-view.get-selection()[0];

    # Rename the use of the variable in the variables hash.
    $v.rename-variable( $original-name, $variable);

    # Rename the use of the variable in the actions list.
    my SessionManager::Actions $actions .= new;
    $actions.subst-vars( $original-name, $variable);

    # Change the row in the listview
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 1, $variable);
    $!statusbar.set-status("Renamed successfully everything");
  }
}

#-------------------------------------------------------------------------------
method variable-modify ( ) {
  $!statusbar.set-status('');
  my SessionManager::Variables $v .= new;

  my Str $variable = $!variable-name.get-text;
  if !$variable {
    $!statusbar.set-status("No variable name specified");
  }

  elsif !$v.get-variable($variable) {
    $!statusbar.set-status("Name '$variable' not existing");
  }

  else {
    # Change the row in the listview
    my $original-pos = $!variables-view.get-selection(:rows)[0];
    if $original-pos.defined {
      $!variables-view.splice( $original-pos, 1, $variable);

      my Str $variable-spec = $!variable-spec.get-text;
      $v.set-variable( $variable, $variable-spec);
      $!statusbar.set-status("Variable $variable modified to '$variable-spec'");
    }

    else {
      $!statusbar.set-status("Cannot modify: no veriable selected in list");
    }
  }
}

#-------------------------------------------------------------------------------
method variable-delete ( ) {
  $!statusbar.set-status('');
  my SessionManager::Variables $v .= new;

  my Str $variable = $!variable-name.get-text;
  if !$variable {
    $!statusbar.set-status("No variable name");
  }

  elsif !$v.get-variable($variable) {
    $!statusbar.set-status("Name '$variable' not defined");
  }
  
  elsif self.check-variable-inuse($variable) {
    $!statusbar.set-status("Variable '$variable' is still in use");
  }

  else {
    $v.remove-variable($variable);
    $!statusbar.set-status("Variable '$variable' removed");
    my UInt $original-pos = $!variables-view.get-selection(:rows)[0];
    $!variables-view.splice( $original-pos, 1);
  }
}

#-------------------------------------------------------------------------------
method !button-row ( --> Box ) {
  my Button $button;
  with my Box $button-row .= new-box( GTK_ORIENTATION_HORIZONTAL, 4) {
    my Label $hstrut = self.make-label;
    $hstrut.set-text('');
    .append($hstrut);

    with $button .= new-button {
      .set-label('Add');
      .register-signal( self, 'variable-add', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Rename');
      .register-signal( self, 'variable-rename', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Modify');
      .register-signal( self, 'variable-modify', 'clicked');
    }
    .append($button);

    with $button .= new-button {
      .set-label('Delete');
      .register-signal( self, 'variable-delete', 'clicked');
    }
    .append($button);
  }

  $button-row
}

#-------------------------------------------------------------------------------
method setup-item ( ) {
  my Label $name = self.make-label;
  my Label $value = self.make-label;
  my Image $used = self.make-image;

  with my Grid $grid .= new-grid {
    .attach( $used, 0, 0, 2, 2);
    .attach( $name, 2, 0, 1, 1);
    .attach( $value, 2, 1, 1, 1);

    .set-size-request( EDIT_WIDTH, -1);
  }

  $grid;
}

#-------------------------------------------------------------------------------
method bind-item ( Gnome::Gtk4::Grid() $grid, Str $name ) {
  my SessionManager::Variables $v .= new;
  my Str $value = $v.substitute-vars($v.get-variable($name));
  self.set-text-at( 2, 0, $name, $grid);
  self.set-text-at( 2, 1, $value, $grid);

  my Bool $name-inuse = self.check-variable-inuse($name);
  self.set-image-at( 0, 0, 'green', $name, $name-inuse, $grid);
}

#-------------------------------------------------------------------------------
method check-variable-inuse ( Str:D $name --> Bool ) {
  # Check if variable is used in the variables store
  my SessionManager::Variables $v .= new;
  my Bool $name-inuse = $v.is-var-in-use($name);

  # If variable is not in use in the variable store, check the
  # use of it in the actions store.
  if !$name-inuse {
    my SessionManager::Actions $actions .= new;
    $name-inuse = $actions.is-var-in-use($name);

    # If variable is not in use in the actions store, check the
    # use of it in the sessions store.
    if !$name-inuse {
      my SessionManager::Sessions $sessions .= new;
      $name-inuse = $sessions.is-var-in-use($name);
    }
  }
  
  $name-inuse
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( Gnome::Gtk4::Grid() $grid ) {
  $grid.clear-object;
}

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
method selection-changed ( UInt $pos, @selections ) {
  my Str $name = @selections[0];
  $!variable-name.set-text($name);
  my SessionManager::Variables $v .= new;
  my Str $value = $v.get-variable($name);
  $!variable-spec.set-text($value);
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
