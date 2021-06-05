extensions [nw]

breed [alives alive];; the turtle is not failed

breed [deads dead];; the turtle is failed

undirected-link-breed [ edges edge ];; the turtle is not failed, so are the edges to the turtle
undirected-link-breed [ failed-edges failed-edge ];; the turtle is failed, so are the edges to the turtle

alives-own ;;normal nodes
[
  infected?           ;; if true, the turtle is infectious
  resistant?          ;; if true, the turtle can't be infected
  untransmissible?    ;; if true, the turtle can't trans virus
  virus-check-timer   ;; number of ticks since this turtle's last virus-check
]

deads-own  ;;failure nodes
[
  infected?           ;; if true, the turtle is infectious
  resistant?          ;; if true, the turtle can't be infected
  untransmissible?    ;; if true, the turtle can't trans virus
  virus-check-timer   ;; number of ticks since this turtle's last virus-check
]

turtles-own [ energy maintenance-check-timer resistenance-duration]       ; both alives and deads have energy,maintenance-cycle, and resistenance-duration

to setup
  random-seed 100 ;;Fixed random seed
  clear-all
  setup-nodes  ;;Initialize nodes and links
  ask alives
    [ set untransmissible? false ]

  ask n-of number-of-untransmissible-nodes alives  ;;Set the number of random nodes as non propagating nodes
    [ set untransmissible? true ]

  ask n-of initial-outbreak-size alives  ;;Set the number of random nodes as the initial infected nodes, corresponding to the risk of malware attack
    [ become-infected ]
  ask n-of initial-damaged-size alives  ;;Set the number of random nodes as the initial failure nodes, corresponding to the physical attack risk
    [ become-failed ]

  ask links [ set color rgb 0 100 175 ] ;;Initializing the color of the edge is beneficial to the visualization of the experimental results.
  reset-ticks
end

to setup-nodes
  set-default-shape alives "circle"
  set-default-shape deads "face sad"

  ;;nw:generate-star alives edges number-of-nodes ;;star topology
  ;;nw:generate-lattice-2d alives edges nb-rows nb-cols true  ;;lattice-2d topology
  nw:generate-random alives edges number-of-nodes connection-prob  ;;random topology

  ;;nw:generate-preferential-attachment alives edges number-of-nodes 1  ;;scale-free
  ;;nw:generate-watts-strogatz alives edges number-of-nodes neighborhood-size rewire-probability  ;;small world
  [
    fd 20
    ;;setxy (random-xcor * 0.95) (random-ycor * 0.95)
    become-susceptible ;;All initial nodes are susceptible.

    set virus-check-timer maintenance-check-frequency ;;The detection cycle of detecting and trying to remove the virus is consistent with the maintenance cycle. The maintenance cycle of each node is not exactly the same（ Limited by total maintenance resources)

    set maintenance-check-timer maintenance-check-frequency ;;The maintenance cycle of each node is not exactly the same（ Limited by total maintenance resources)

    set energy random battery-power ;;Initialize the remaining power of the battery, and the initial power is not less than half of the maximum power.
    if energy < battery-power / 2
      [set energy energy + battery-power / 2]
  ]
end

to go
  random-seed 100
  if ticks >= 400 [ stop ] ;;Maximum simulation time 400 ticks
  if all? turtles [not infected?];;If there are no infected nodes and no failed nodes, the simulation stops.
    [ if not any? deads
      [ stop ]]
  ask alives  ;;Countdown and reset of virus detection, detection cycle = maintenance cycle
  [
     set virus-check-timer virus-check-timer + 1
     if virus-check-timer >= maintenance-check-frequency
       [ set virus-check-timer 0 ]
  ]
    ask deads  ;;Maintenance cycle countdown and reset
  [
     set maintenance-check-timer maintenance-check-timer + 1
     if maintenance-check-timer >= maintenance-check-frequency
       [ set maintenance-check-timer 0 ]
  ]
  do-fail  ;;Based on the design of component failure, the nodes fail and change from normal state to failure state
  loss-of-resistance  ;;The node in recovery state loses the immunity temporarily obtained. The duration of immunity is related to the security level and infection intensity, that is, the technical strength of both attack and defense sides.
  spread-virus  ;;Each infected node propagates malware to the surrounding nodes.
  do-virus-checks  ;;According to the detection cycle, detect and remove malware.According to the detection cycle, detect and remove malware. This operation is a batch operation in the information space and does not consume manpower (maintenance resources)

  do-maintenance  ;;Non military maintenance work, charging or replacing batteries for sensors with insufficient power, consumes 0.5% of maintenance resources; To repair the failed sensor, 1 maintenance resource is consumed; If resources are exhausted, they cannot be maintained.
  ;;do-maintenance-military  ;;Military maintenance work, can not charge or repair, can only directly replace the failure of the sensor, consumption of maintenance resources 2; If resources are exhausted, they cannot be maintained.
  nw:set-context alives links  ;;The function provided by NW extension can select the subgraph composed of normal nodes and their edges from the current graph
  ;;color-clusters nw:bicomponent-clusters
  color-clusters nw:weak-component-clusters  ;;Give each weak-component-cluster in the sub-graph different colors.
  nw:set-context turtles links  ;;Make the whole graph the activity graph again.
  tick
end

to color-clusters [ clusters ]  ;;The color of MCC is [RGB 0 100 200]. As long as the number of nodes in this color is reported, the number of MCC will be obtained.
  ; reset all colors
  ask turtles [ set color gray ]
  ask links [ set color gray - 2 ]
  let n length clusters
  ; Generate a unique hue for each cluster
  let hues n-values n [ i -> (255 * i / n) ]

  let sorted-clusters sort-by [ [c1 c2] -> count c1 > count c2 ] clusters
  ; loop through the clusters and colors zipped together
  (foreach sorted-clusters hues [ [sorted-cluster hue] ->
    ask sorted-cluster [ ; for each node in the cluster
                  ; give the node the color of its cluster
      set color rgb hue 100 200
      ; Color links contained in the cluster slightly darker than the cluster color
      ask my-links with [ member? other-end sorted-cluster ] [ set color rgb hue 100 175 ]
    ]
  ])
end

to become-failed ;;Node failure, can no longer be infected; From normal state to failure state.
  ;;set infected? true
  set resistant? true
  set breed deads
  set shape "face sad"
end


to become-infected  ;;
  set infected? true
  set resistant? false
  set shape "bug"
  set breed alives
end

to become-susceptible  ;; turtle procedure
  set infected? false
  set resistant? false
  set color rgb 0 100 200
  set breed alives
end

to become-resistant  ;; turtle procedure

  set infected? false
  set resistant? true
  set resistenance-duration temporary-resistance
  set shape "box"
  set breed alives
end

to spread-virus
  ask turtles with [infected? and untransmissible? = false]
    [ ask link-neighbors with [not resistant?]
        [ if random-float 100 < virus-spread-chance
            [ become-infected ] ] ]
end

to do-fail
  ask alives
  [ifelse infected? = true
    [
    if random 100 < failure-rate + 10  ;;industry Malware infection increases the failure rate by 10%.
    ;;if random 100 < failure-rate + 20  ;;military Malware infection increases the failure rate by 20%.
    [become-failed]]
    [
    if random 100 < failure-rate  ;;Random failure.
    [become-failed]]
  ]
  ask alives  ;;The remaining power is no more than 0, and it is failed
    [ifelse energy > 0
      [set energy energy - 1]  ;;The power consumption for normal operation is 1
      [become-failed]]
  ask alives with [infected?]
    [ifelse energy > 0
      [set energy energy - malware-energy-consumption]  ;;After being infected by malware, the power consumption increases by malware-energy-consumption
      [become-failed]]
end

to do-virus-checks  ;;The detection period of infected nodes is found, which may be restored to susceptibility or temporarily immune.
  ask other alives with [infected? and virus-check-timer = 0]
  [
    if random 100 < recovery-chance
    [
      ifelse random 100 < gain-resistance-chance  ;;These probabilities are related to security level and infection density.
        [ become-resistant ]
        [ become-susceptible ]
    ]
  ]
end

to loss-of-resistance  ;;Loss of temporarily acquired immunity.
  ask alives with [resistant?]
  [
    ifelse resistenance-duration = 0
    [become-susceptible]
    [set resistenance-duration resistenance-duration - 1]
  ]
end

to do-maintenance  ;;Common maintenance
  let local-maintenance-workers maintenance-workers
  ask alives with [maintenance-check-timer = 0 and local-maintenance-workers > 0]  ;;The current power is less than 20% of the maximum power, charging consumes 0.5 resources
  [
    if energy < battery-power / 5
    [set energy battery-power
      set local-maintenance-workers local-maintenance-workers - 0.5]]
  ask deads with [maintenance-check-timer = 0]  ;;Repair failure node, consume resource 1
  [
    if local-maintenance-workers > 0
      [ become-susceptible
        set local-maintenance-workers local-maintenance-workers - 1
        show local-maintenance-workers
      ]
  ]
end

to do-maintenance-military  ;;military maintenance
  let local-maintenance-workers maintenance-workers
  ask deads with [maintenance-check-timer = 0]  ;;Unable to charge or repair, replace the failed sensor with the intact sensor directly, and consume resources 2
  [
    if local-maintenance-workers > 0
      [ become-susceptible
        set energy battery-power
        set local-maintenance-workers local-maintenance-workers - 2
        show local-maintenance-workers
      ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
265
10
842
588
-1
-1
13.9
1
10
1
1
1
0
0
0
1
-20
20
-20
20
1
1
1
ticks
30.0

SLIDER
25
552
230
585
gain-resistance-chance
gain-resistance-chance
0.0
100
20.0
1
1
%
HORIZONTAL

SLIDER
25
517
230
550
recovery-chance
recovery-chance
0
100
20.0
1
1
%
HORIZONTAL

SLIDER
25
447
230
480
virus-spread-chance
virus-spread-chance
0
100
30.0
1
1
%
HORIZONTAL

BUTTON
26
252
121
292
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
136
252
231
292
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
3
593
830
830
Network Status
time
% of nodes
0.0
400.0
0.0
100.0
true
true
"" ""
PENS
"normal" 1.0 0 -2674135 true "" "plot (count alives) / (count turtles) * 100"
"failure" 1.0 0 -16777216 true "" "plot (count deads) / (count turtles) * 100"
"infected" 1.0 0 -7500403 true "" "plot (count alives with [infected?]) / (count turtles) * 100"
"MCC" 1.0 0 -10899396 true "" "plot (count turtles with [color = [0 100 200]]) / (count turtles) * 100"

SLIDER
25
15
230
48
number-of-nodes
number-of-nodes
10
300
140.0
5
1
NIL
HORIZONTAL

SLIDER
25
482
230
515
virus-check-frequency
virus-check-frequency
1
20
2.0
1
1
ticks
HORIZONTAL

SLIDER
25
85
230
118
initial-outbreak-size
initial-outbreak-size
1
number-of-nodes
3.0
1
1
NIL
HORIZONTAL

SLIDER
997
94
1169
127
nb-rows
nb-rows
1
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
998
131
1170
164
nb-cols
nb-cols
1
20
14.0
1
1
NIL
HORIZONTAL

SLIDER
995
167
1176
200
clustering-exponent
clustering-exponent
0.1
10
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
24
50
231
83
number-of-untransmissible-nodes
number-of-untransmissible-nodes
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
1002
315
1174
348
neighborhood-size
neighborhood-size
0.5
5
3.0
0.5
1
NIL
HORIZONTAL

SLIDER
1001
352
1175
385
rewire-probability
rewire-probability
0
1
0.1
0.01
1
NIL
HORIZONTAL

TEXTBOX
1005
289
1237
307
small world Watts–Strogatz parameter
12
0.0
1

SLIDER
988
692
1191
725
maintenance-workers
maintenance-workers
0
40
25.0
1
1
NIL
HORIZONTAL

SLIDER
986
727
1191
760
maintenance-check-frequency
maintenance-check-frequency
1
10
2.0
1
1
ticks
HORIZONTAL

SLIDER
991
574
1194
607
battery-power
battery-power
1
40
15.0
1
1
NIL
HORIZONTAL

SLIDER
991
609
1194
642
malware-energy-consumption
malware-energy-consumption
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
25
123
230
156
initial-damaged-size
initial-damaged-size
0
100
5.0
1
1
NIL
HORIZONTAL

SLIDER
24
411
230
444
temporary-resistance
temporary-resistance
0
50
4.0
1
1
NIL
HORIZONTAL

SLIDER
24
375
228
408
failure-rate
failure-rate
0
100
10.0
1
1
%
HORIZONTAL

SLIDER
1032
465
1204
498
connection-prob
connection-prob
0.00
1.00
0.03
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
Experiment on the integration of physical failure and malware propagation.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
