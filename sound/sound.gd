extends Node

onready var music = AudioStreamPlayer.new()
# Music that's being faded out is transferred here by swapping instances around.
# This implies that if a music set occurs too immediately, a cross-fade occurs.
onready var _music_fading = AudioStreamPlayer.new()
# This is the amount of time after the fading music has completely faded,
#  but before it's actually stopped.
# This allows a fading song to be "brought back from the dead".
# Ideally, this wouldn't need to happen, but map transitions fade-out,
#  and sometimes they are transitions between identical tracks.
var _music_fading_shutdown_time = 0.0
# Always check _music_fading.playing before using this.
# - but it may not have actually started yet.
var _fading_song = ""

# Note that due to the problems with how music volume is managed in decibels,
#  this shutdown time will cause odd 'background quiet music' if set too high.
const MUSIC_FADING_SHUTDOWN_TIME = 1.0

var current_song = ""
var gameover = false

const DEFAULT_SFX_VOLUME = -15
const DEFAULT_MUSIC_VOLUME = -20
const QUIET_MUSIC_VOLUME = -27.5

# Godot uses decibels as the measurement.
# In decibels, '-inf' is silent.
# Actually using this would mess up all of the calculations.
# Therefore, define some value that is considered effectively silent.
const SILENT_MUSIC_VOLUME = -50

var music_volume = DEFAULT_MUSIC_VOLUME
# Arguably needs to be changed to some other unit. For now, leave as-is
var _music_lerp_speed = 0.0
const MUSIC_LERP_SPEED_NORMAL = 0.1
const MUSIC_LERP_SPEED_FADINGREVIVE = 0.05

func _ready():
	add_child(music)
	add_child(_music_fading)

func _process(delta):
	var can_new_music_start = true
	if _music_fading.playing:
		if _music_fading.volume_db <= SILENT_MUSIC_VOLUME:
			if _music_fading_shutdown_time > 0.0:
				_music_fading_shutdown_time -= delta
			else:
				# This makes sure the old track gets unloaded eventually.
				# But more importantly, it allows a new track to take over.
				_music_fading.stop()
				_music_fading.stream = null
		else:
			# Still fading out.
			can_new_music_start = false
			_music_fading.volume_db -= delta * 30
	# Start any queued music track.
	if can_new_music_start:
		if music.stream != null:
			if not music.playing:
				music.play()
	# If the music's playing, manage volume.
	if music.playing:
		# print(music.volume_db, " @ ", _music_lerp_speed)
		music.volume_db = lerp(music.volume_db, music_volume, _music_lerp_speed)

func fadeout_music():
	var old_song = current_song
	current_song = ""
	# Importantly, try to deduplicate repeated calls.
	# If the music never actually started, this instance is reusable as-is.
	if music.playing:
		# This instance is in-use.
		# Swap it into the fading track position.
		# Whatever's in the fading track position will be shutdown.
		var tmp = music
		music = _music_fading
		_music_fading = tmp
		_music_fading_shutdown_time = MUSIC_FADING_SHUTDOWN_TIME
		_fading_song = old_song
	# Clean the existing track instance so it's like-new.
	music.stop()
	music.stream = null
	music.volume_db = SILENT_MUSIC_VOLUME

# This is a specific set of horrible things to swap fading music back into play.
# It assumes that _music_fading is known to be playing.
# It assumes nothing about the state of the current music.
func _revive_fading():
	# Swap music
	var old_music = music
	music = _music_fading
	_music_fading = old_music
	# Swap song
	var old_song = current_song
	current_song = _fading_song
	_fading_song = old_song
	# Setup shutdown time
	_music_fading_shutdown_time = MUSIC_FADING_SHUTDOWN_TIME

func set_music(song, musicfx = ""):
	var fx = {}
	for v in musicfx.split(","):
		fx[v] = true
	if gameover == false:
		music_volume = DEFAULT_MUSIC_VOLUME
		_music_lerp_speed = MUSIC_LERP_SPEED_NORMAL
		# Need to work out how to arrange the song change.
		# Firstly, if we're already playing the song, we don't need to change it.
		var song_change = song != current_song
		if song_change:
			# Secondly, if we were JUST playing the song, revive it.
			if song == _fading_song and _music_fading.playing:
				# revive fading track
				_revive_fading()
				# this is no longer really a song change
				song_change = false
				# lower lerp speed for better continuity -
				#  we just faded out from it after all
				_music_lerp_speed = MUSIC_LERP_SPEED_FADINGREVIVE
			else:
				# shift out the existing track
				fadeout_music()
				if song != "":
					var path = str("res://sound/music/", song, ".ogg")
					music.stream = load(path)
					# Music will be started when the previous track is gone.
				current_song = song
		# FX handling
		if fx.has("quiet"):
			music_volume = QUIET_MUSIC_VOLUME
		if song_change:
			# fadein in particular is only usable on a song change,
			#  because it *only* affects initial fade-in.
			# Otherwise it would affect volume transitions.
			# Not on by default because it cuts off early notes.
			# Must be placed after all music_volume controllers.
			if not fx.has("fadein"):
				# Start the music at full volume.
				music.volume_db = music_volume
		if fx.has("immediate") and not music.playing:
			# Don't wait for fade-out.
			# Must be at the end.
			music.play()

func play(sound, volume=0):
	var path = str("res://sound/sfx/", sound, ".ogg")
	var new_sound = AudioStreamPlayer.new()
	get_tree().get_root().add_child(new_sound)
	new_sound.set_stream(load(path))
	new_sound.set_volume_db(DEFAULT_SFX_VOLUME + volume)
	new_sound.connect("finished", new_sound, "queue_free")
	new_sound.play()
