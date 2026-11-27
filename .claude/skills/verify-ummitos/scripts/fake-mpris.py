import dbus, dbus.service, dbus.mainloop.glib
from gi.repository import GLib
dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
bus = dbus.SessionBus()
name = dbus.service.BusName('org.mpris.MediaPlayer2.fake', bus)
ROOT = {'CanQuit': False, 'CanRaise': False, 'HasTrackList': False, 'Identity': 'Fake', 'SupportedUriSchemes': dbus.Array([], signature='s'), 'SupportedMimeTypes': dbus.Array([], signature='s')}
META = dbus.Dictionary({'mpris:trackid': dbus.ObjectPath('/fake/1'), 'xesam:title': "[MV] 아일릿 (ILLIT) '체포하겠어 (Arrest Me)' Official Music Video", 'xesam:artist': dbus.Array(['HYBE LABELS'], signature='s'), 'mpris:length': dbus.Int64(200000000)}, signature='sv')
PLAYER = {'PlaybackStatus': 'Playing', 'LoopStatus': 'None', 'Rate': 1.0, 'Shuffle': False, 'Metadata': META, 'Volume': 1.0, 'Position': dbus.Int64(30000000), 'MinimumRate': 1.0, 'MaximumRate': 1.0, 'CanGoNext': False, 'CanGoPrevious': False, 'CanPlay': True, 'CanPause': True, 'CanSeek': False, 'CanControl': True}
class P(dbus.service.Object):
    def props(self, i): return ROOT if i == 'org.mpris.MediaPlayer2' else PLAYER
    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ss', out_signature='v')
    def Get(self, i, p): return self.props(i)[p]
    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='s', out_signature='a{sv}')
    def GetAll(self, i): return dbus.Dictionary(self.props(i), signature='sv')
    @dbus.service.method('org.freedesktop.DBus.Properties', in_signature='ssv')
    def Set(self, i, p, v): pass
    @dbus.service.method('org.mpris.MediaPlayer2')
    def Raise(self): pass
    @dbus.service.method('org.mpris.MediaPlayer2')
    def Quit(self): pass
    @dbus.service.method('org.mpris.MediaPlayer2.Player')
    def PlayPause(self): pass
P(bus, '/org/mpris/MediaPlayer2')
GLib.MainLoop().run()
