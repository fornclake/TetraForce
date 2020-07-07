extends Node

var current_map = null
var player_list = {} # player, map

var current_players = []
var map_peers = []

func _ready():
	set_process(false)
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")

### PLAYER LIST UPDATES ###
# super important. list of every player in the game & what map they're in
#
# 1) client connects
# 2) client sends id and map to server
# 3) server adds id and map as a key/value pair in player_list dictionary
# 4) server sends player_list to every client
# 5) update_players() gives network.gd a list of all players in current room
#    and a list of all OTHER players in current room (current_players & map peers)
# 6) game.gd then takes this list of players, compares it to the player nodes
#    it has in the room, removes the ones that are no longer there, and adds
#    the ones that have just entered
#

func send_current_map(): # called when a player enters a new map
	if get_tree().is_network_server():
		# server adds itself to the list and updates everyone
		_receive_current_map(1, current_map.name)
	else:
		# every one else first sends their information to the server, and then it updates everyone
		rpc_id(1, "_receive_current_map", get_tree().get_network_unique_id(), current_map.name)

remote func _receive_current_map(id, map): # server receives map from client
	player_list[id] = map
	rpc("_receive_player_list", player_list)
	update_players() # server updates its own map peers

remote func _receive_player_list(list): # client receives player list from server
	player_list = list
	update_players() # client updates map peers

func update_players(): # gets list of all players in map AND all other players
	current_players = []
	map_peers = []
	# get all players in current_map
	for id in player_list:
		if player_list[id] == player_list[get_tree().get_network_unique_id()]:
			current_players.append(id)
	# get all players besides self in current_map
	for player in current_players:
		if player != get_tree().get_network_unique_id():
			map_peers.append(player)
	
	# *** IMPORTANT *** #
	# this is where game.gd gets that information and updates the puppets
	current_map.update_puppets()

func _player_disconnected(id): # remove disconnected players from player_list
	if get_tree().is_network_server():
		player_list.erase(id)
		rpc("_receive_player_list", player_list)
		update_players()
