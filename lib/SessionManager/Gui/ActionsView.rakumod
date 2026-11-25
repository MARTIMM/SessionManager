use v6.d;

use SessionManager::Config;
use SessionManager::Actions;
use SessionManager::Sessions;

use SessionManager::Gui::EditTools;

use GnomeTools::Gtk::ListView;

use Gnome::Gtk4::Grid:api<2>;
use Gnome::Gtk4::Label:api<2>;
use Gnome::Gtk4::Image:api<2>;

use Gnome::N::GlibToRakuTypes:api<2>;

#-------------------------------------------------------------------------------
unit class SessionManager::Gui::ActionsView;
also is GnomeTools::Gtk::ListView;

constant Grid = Gnome::Gtk4::Grid;
constant Label = Gnome::Gtk4::Label;
constant Image = Gnome::Gtk4::Image;


has SessionManager::Config $!config;
has SessionManager::Actions $!actions;
has SessionManager::Sessions $!sessions;

has Str $!sessionid;

#-------------------------------------------------------------------------------
submethod BUILD ( Bool :$multi-select, SupplyCode :$supply-code ) {
  $!config .= instance;
  $!actions .= new;
  $!sessions .= new;

  with self {

    .set-setup( self, 'setup-item');
    .set-bind( self, 'bind-item');
#    .set-unbind( self, 'unbind-item');
    .set-teardown( self, 'teardown-item');

#    .set-selection-changed( self, 'change-action-selection');

    .append($!actions.get-action-ids.sort: {$^a.lc leg $^b.lc});
  }

  # Setup a tap to listen for notifications
  $!config.get-supply.tap(
    -> Hash $command {

      # It's for us only when the code is PROCESS_ACTION_CHANGES
      next unless $command<code> ~~ $supply-code;

      # With it, there are other keys at the same level for the operations.
      with $command {
        when .<splice>:exists {
          self!splice-listview( .<nremove>, .<replace>);
        }

        when .<fill>:exists {
          self!fill-listview( .<sessionid>, .<items>);
        }
      }
    }
  );
}

#--[tap commands]---------------------------------------------------------------
method !splice-listview ( UInt $n-remove, @replace) {
  my UInt $pos = self.get-selection(:rows)[0] // 0;
  if ?@replace {
    self.splice( $pos, $n-remove, @replace);
  }

  else {
    self.splice( $pos, $n-remove, gpointer);
  }
}

#-------------------------------------------------------------------------------
method !fill-listview ( Str $!sessionid, @items ) {
  self.remove(self.get-n-items);
  self.append(@items);
}

#--[listview callbacks]---------------------------------------------------------
method setup-item ( ) {
  my Label $action-id = make-label;
  my Label $action-value = make-label;
  my Image $used = make-image;

  with my Grid $grid .= new-grid {
    .attach( $used, 0, 0, 2, 2);
    .attach( $action-id, 2, 0, 1, 1);
    .attach( $action-value, 2, 1, 1, 1);
  }

  $grid;
}

#-------------------------------------------------------------------------------
method bind-item ( Gnome::Gtk4::Grid() $grid, Str $name ) {
  my Hash $action-object = $!actions.get-raw-action($name);

  set-text-at( 2, 0, $name, $grid);
  set-text-at( 2, 1, $action-object<t>//'', $grid);

  my Bool $name-inuse = $!sessions.is-action-in-use-in-session(
    $!sessionid, $name
  );

  set-image-at( 0, 0, 'green', $name-inuse, $grid);
}

#-------------------------------------------------------------------------------
#method unbind-item

#-------------------------------------------------------------------------------
method teardown-item ( Gnome::Gtk4::Grid() $grid ) {
  $grid.clear-object;
}
