Inspired by a recent thread about Terry Riley’s In C I thought it would be a fun exercise to write a norns script to play it.

I’ve probably made mistakes transcribing the music so let me know (or send a pull request) if you notice anything.

Requirements

norns
MIDI (optional)
mx.samples (optional)

Documentation

K2 - Start / Stop play
K3 - Go back to the start

It will output MIDI, crow (not tested) or audio using PolyPerc as the default engine but sounds really nice using mx.samples as the engine with different instruments for each player. There are params for the probability of repeating a phrase rather than moving on and to limit how far the players can get ahead of the furthest behind.