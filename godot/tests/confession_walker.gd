## A stand-in for the witness path in test_confession.gd: the sheet reads
## only the walker's position and the right hand from its parent.
extends Node3D

var pos := Vector3.ZERO
var right_hand: XRController3D = null
