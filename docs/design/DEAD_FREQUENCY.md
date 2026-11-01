# Dead Frequency radio mimicry — P3-14

The host retains at most 80 recent 20 ms ADPCM radio frames per speaking teammate (1.6 seconds). History expires after 10 seconds of silence, and new speech starts a fresh history. When a player's Sanity band reaches Broken, the host can replay a teammate's recent radio speech to that victim only. Frames are sent in reverse order at the original 20 ms cadence, and each decoded frame is reversed and softened on the receiver. The existing VoiceRadio bus gives the imitation the same radio filtering and squelch as normal transmissions.

The injection uses a host-authority RPC on voice channel 2. It never enters proximity playback, the microphone transmit path, AI voice noise, or another player's radio. The host applies a 35-second cooldown per victim and discards history and pending imitations when the speaker leaves or the session ends. With no recent teammate radio speech, there is no imitation; the existing phantom ring/footstep effects still cover low sanity.

Verification: five `test_dead_frequency.gd` cases check bounded and fresh history, packet validation, cooldown, and disconnect cleanup. The ENet case runs a host, victim, and bystander and confirms only the victim receives the fake radio frame. A live listening test should confirm the effect sounds right and remains isolated.
