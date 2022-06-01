;; Types of Turtle
breed [patients patient]        ;; A breed of turtle to represent patients
breed [caregivers caregiver]    ;; A breed of turtle to represent caregivers
breed [minorcaregivers minorcaregiver]  ;; A breed of turtle that can only treat minors patients
breed [mylabels mylabel]        ;; A breed to allow us to add labels to the plot

;; Global Variables
globals[
  poisson_random_1
  poisson_random_2
  poisson_random_3
  dist_patient_lv1_fq           ;; Distribution of frequency of creation of lv 1 patients
  dist_patient_lv2_fq           ;; Same for level 2
  dist_patient_lv3_fq           ;; Same for level 3
  dist_lv1_treatment_times      ;; Amount of treatment time required for lv 1 patient
  dist_lv2_treatment_times      ;; Same for level 2
  dist_lv3_treatment_times      ;; Same for level 3
  dist_lv1_arrival_type         ;; Defines the arrival location/type - ambulance or waiting room
  dist_lv2_arrival_type         ;; Same for level 2
  dist_lv3_arrival_type         ;; Same for level 3
  simticks                      ;; This is a variable I'm going to use to give track of time
  minor_size                    ;; Number of minor spaces
  major_size                    ;; Number of major spaces
  resus_size                    ;; Number of resus spaces
  waittime_ambulance_avg        ;; Variable to hold a calculation of waiting time average for ambulance
  waittime_ambulance_max        ;; Variable to hold a calculation of waiting time max for ambulance
  waittime_waitroom_avg         ;; Variable to hold a calculation of waiting time average for waiting room
  waittime_waitroom_max         ;; Variable to hold a calculation of waiting time max for waiting room
  total_waittime_avg            ;; Variable to hold a calculation of waiting time total average for simulation
  total_waittime_max            ;; Variable to hold a calculation of waiting time total sum for simulation
  dead_patients
  death_prob

  ]

;; Turtle Variables
patients-own[
  pt_severity                ;; Current severity (could be dynamic)
  pt_severity_initial        ;; Arrival severity
  pt_creation_time           ;; Time created
  pt_treatment_time          ;; Treatment time remaining (dynamic)
  pt_treatment_time_initial  ;; Treatment time initial
  pt_location                ;; Location of patient
  pt_arrival_type            ;; How patient arrived
  pt_waitingtime             ;; How long is patient in department
  pt_allocated_caregiver     ;; Is patient currently allocated caregiver (binary)
]

caregivers-own[
  caregiver_available        ;; Is caregiver currently available
]

minorcaregivers-own[
  minorcaregiver_available
]

;; Possible Patient Locations
;; 11 = Ambulance Bay     ;; 12 = Waiting Room
;; 21 = Minors            ;; 22 = Majors           ;; 23 = Resus
;; 91 = Discharged

;; ===============
;; Setup procedure - Get the simulation ready
;; ===============

to setup
  clear-all                                              ;; Resets the environment
  reset-ticks                                            ;; Resets the built in clock
  setup-background
  ;;set poisson_random_1 random-poisson 6
  ;;set poisson_random_2 random-poisson 4
  ;;set poisson_random_3 random-poisson 3
  ;;set dist_patient_lv1_fq (list poisson_random_1 poisson_random_2 poisson_random_3)                                        ;; A set of values this variable can take
  ;;set dist_patient_lv2_fq (list poisson_random_1 poisson_random_2 poisson_random_3)
  ;;set dist_patient_lv3_fq (list poisson_random_1 poisson_random_2 poisson_random_3)
  set dist_patient_lv1_fq [0 0 1 1 1 1 2 3 4 5]          ;; A set of values this variable can take
  set dist_patient_lv2_fq [0 0 0 0 1 1 1 2 2 3]          ;; as above. etc
  set dist_patient_lv3_fq [0 0 0 0 0 0 0 0 1 2]
  set dist_lv1_treatment_times [1 1 1 1 1 1 2 2 3 3]     ;; These distributions say that the options for
  set dist_lv2_treatment_times [3 3 3 3 4 4 5 6 8 9]     ;; this value can be any of these numbers
  set dist_lv3_treatment_times [6 6 6 6 6 7 7 8 9 12]    ;; This could be any distribution you wanted
  set dist_lv1_arrival_type [12]                         ;; At present, I've said this distribution can only be one value
  set dist_lv2_arrival_type [12 12 12 11 11]             ;; Potential arrival types for lvl 2 patients
  set dist_lv3_arrival_type [11]
  set-default-shape caregivers "circle"
  set-default-shape minorcaregivers "square"
  set-default-shape patients "person"
  create-caregivers caregivers_number  [set color blue setxy -5 14]
  create-minorcaregivers minorcaregivers_number [set color violet setxy -5 15]
  set minor_size minor_size_slider    ;; Minors has this many units
  set major_size major_size_slider    ;; Majors has this many units
  set resus_size resus_size_slider    ;; Resus has this many units
  setup-patches
end

to setup-background
  ask patches with [ pxcor <= -11]
  [
    set pcolor blue
  ]
end

;; Setup patches
to setup-patches
ask patch -5 8 [set pcolor green]
ask patch -5 0 [set pcolor orange]
ask patch -5 -8 [set pcolor red]

create-mylabels 1 [setxy -5 9 set label "Minors units" set color black]
create-mylabels 1 [setxy -5 1 set label "Majors units" set color black]
create-mylabels 1 [setxy -5 -7 set label "Resus units" set color black]
end

;; ====================
;; Main simulation code - Runs on repetition with click of go button
;; ====================

to go
  IF precision ticks 2 > timeStop [stop]
  move-clock
  make-newpatients
  move-lvl3patients-maj-resus
  admit-lvl3patients-resus
  admit-lvl3patients-major
  admit-lvl2patients-major
  admit-lvl1patients-minor
  allocate-minorcaregivers
  allocate-caregivers
  treat-patients
  discharge-patients
  animate-patients-1
  calculate-variables
  move-caregivers-minorgivers
  tick
end

to animate-patients-1
  ask patients with [xcor < -4 AND pt_location = 23][setxy -4 -8]
  ask patients with [xcor < -4 AND pt_location = 22][setxy -4 0]
  ask patients with [xcor < -4 AND pt_location = 21][setxy -4 8]
  animate-patients-2
  move-caregivers
end

to animate-patients-2
  ask patients with [xcor = -4][animate-movetofreespace]
end

to animate-movetofreespace
   set xcor xcor + 0.5
   if any? other patients-here [set xcor xcor + 1 animate-movetofreespace]
end

to move-caregivers
  ask links [transfer-xcor]

end

to transfer-xcor
  let temp_xcor [xcor] of end2
  let temp_ycor [ycor] of end2
  ask end1 [setxy temp_xcor temp_ycor + 2]
end

to move-caregivers-minorgivers
  ask caregivers with [caregiver_available = 1] [setxy -5 12]
  ask minorcaregivers with [minorcaregiver_available = 1] [setxy -4 12]
end


;; ===========
;; World Clock - 1 tick is 10 minutes
;; ===========

to move-clock
  set simticks simticks + 1
  ask patients with [pt_location < 91] [set pt_waitingtime pt_waitingtime + 1]
  ask patients with [xcor < -5][set ycor ycor + 1]
  ask patients with [pt_location < 14][set label pt_waitingtime]
  ask patients with [pt_location > 20][set label pt_treatment_time]
end

;; ===============
;; Patient Creator - Make new patients
;; ===============

to make-newpatients
 create-patients one-of dist_patient_lv1_fq                   ;; Make n number of patients where n is one of the distribution for this patient severity
  [set pt_severity_initial 1                                  ;; Set variable initial severity to 1
   set pt_severity 1                                          ;; Set variable severity to 1
   set pt_treatment_time one-of dist_lv1_treatment_times      ;; Pick one of the treatment times and set this patient's treatment time variable to this value
   set pt_treatment_time_initial pt_treatment_time
   set pt_arrival_type one-of dist_lv1_arrival_type           ;; Set an arrival type
   set pt_location pt_arrival_type
   set pt_creation_time simticks                              ;; Set when we created them
   set color green                                            ;; Set a color
   IF pt_arrival_type = 11 [set pt_waitingtime 6]

   set xcor -16 + random-float 1
   set ycor -16
   ]
 create-patients one-of dist_patient_lv2_fq
  [set pt_severity_initial 2
   set pt_severity 2
   set pt_treatment_time one-of dist_lv2_treatment_times
   set pt_treatment_time_initial pt_treatment_time
   set pt_arrival_type one-of dist_lv2_arrival_type
   set pt_location pt_arrival_type
   set pt_creation_time simticks
   set color orange
   set label pt_creation_time
   IF pt_arrival_type = 11 [set pt_waitingtime 6 set color blue]

   set xcor -14 + random-float 1
   set ycor -16
   ]
 create-patients one-of dist_patient_lv3_fq
  [set pt_severity_initial 3
   set pt_severity 3
   set pt_treatment_time one-of dist_lv3_treatment_times
   set pt_treatment_time_initial pt_treatment_time
   set pt_arrival_type one-of dist_lv3_arrival_type
   set pt_location pt_arrival_type
   set pt_creation_time simticks
   set label pt_creation_time
   set color red
   IF pt_arrival_type = 11 [set pt_waitingtime 6]
   set xcor -12 + random-float 1
   set ycor -16
   ]
end

;; ==========================
;; MOVE PATIENTS TO NEW AREAS
;; ==========================

to admit-lvl3patients-resus
let temp_resus_spaces resus_size - count patients with [pt_location = 23]
IF temp_resus_spaces < 1 [stop]
IF count patients with [pt_severity = 3 AND ((pt_location = 11) OR (pt_location = 12))] < 1 [stop]
ASK max-one-of patients with [pt_severity = 3 AND ((pt_location = 11) OR (pt_location = 12))][pt_waitingtime]
    [set pt_location 23]
    admit-lvl3patients-resus
end

to move-lvl3patients-maj-resus
let temp_resus_spaces resus_size - count patients with [pt_location = 23]
IF temp_resus_spaces < 1 [stop]
IF count patients with [pt_severity = 3 AND pt_location = 22] < 1 [stop]
ASK max-one-of patients with [pt_severity = 3 AND pt_location = 22][pt_waitingtime]
    [set pt_location 23]
end

to admit-lvl3patients-major
let temp_major_spaces major_size - count patients with [pt_location = 22]
IF temp_major_spaces < 1 [stop]
IF count patients with [pt_severity = 3 AND ((pt_location = 11) OR (pt_location = 12))] < 1 [stop]
ASK max-one-of patients with [pt_severity = 3 AND ((pt_location = 11) OR (pt_location = 12))][pt_waitingtime]
    [set pt_location 22]
    admit-lvl3patients-resus
end

to admit-lvl2patients-major
let temp_major_spaces major_size - count patients with [pt_location = 22]
IF temp_major_spaces < 1 [stop]
IF count patients with [pt_severity = 2 AND ((pt_location = 11) OR (pt_location = 12))] < 1 [stop]
ASK max-one-of patients with [pt_severity = 2 AND ((pt_location = 11) OR (pt_location = 12))][pt_waitingtime]
    [set pt_location 22]
    admit-lvl2patients-major
end

to admit-lvl1patients-minor
let temp_minor_spaces minor_size - count patients with [pt_location = 21]
IF temp_minor_spaces < 1 [stop]
IF count patients with [pt_severity = 1 AND ((pt_location = 11) OR (pt_location = 12))] < 1 [stop]
ASK max-one-of patients with [pt_severity = 1 AND ((pt_location = 11) OR (pt_location = 12))][pt_waitingtime]
    [set pt_location 21]
    admit-lvl1patients-minor
end

;; ===============================
;; Allocate caregivers to patients
;; ===============================

to allocate-caregivers
Ask caregivers [if count out-link-neighbors > 0 [set caregiver_available 0]]   ;; If you have a link to a neighbour, mark yourself unavailable
Ask caregivers [if count out-link-neighbors = 0 [set caregiver_available 1]]   ;; If you don't have any links, mark yourself available
Ask patients [if count in-link-neighbors > 0 [set pt_allocated_caregiver 1]]  ;; If you do have a linked caregiver, mark yourself allocated
Ask patients [if count in-link-neighbors = 0 [set pt_allocated_caregiver 0]]  ;; If you don't have any links to a caregiver, mark youself unallocated
IF count patients with [pt_allocated_caregiver = 0] = 0 [stop]  ;; Stop if there are no patients reporting no caregiver
IF count caregivers with [caregiver_available = 1] = 0 [stop]   ;; Stop if there are no caregivers reporting themselves available

;; Beginning in resus, if there is an unallocated patient, we ask a caregiver to join with longest wait.
IF count patients with [pt_allocated_caregiver = 0 AND pt_location = 23] > 0
     [ ask one-of caregivers with [caregiver_available = 1]
                [create-link-to max-one-of patients with [pt_location = 23 AND pt_allocated_caregiver = 0][pt_waitingtime] set color red
     allocate-caregivers     ]]

;; Repeat for major and minors
IF count caregivers with [caregiver_available = 1] = 0 [stop]
IF count patients with [pt_allocated_caregiver = 0 AND pt_location = 22] > 0
     [ ask one-of caregivers with [caregiver_available = 1]
         [create-link-to max-one-of patients with [pt_location = 22 AND pt_allocated_caregiver = 0][pt_waitingtime] set color orange
       allocate-caregivers ]]

IF count caregivers with [caregiver_available = 1] = 0 [stop]
IF count patients with [pt_allocated_caregiver = 0 AND pt_location = 21] > 0
     [ask one-of caregivers with [caregiver_available = 1]
         [create-link-to max-one-of patients with [pt_location = 21 AND pt_allocated_caregiver = 0][pt_waitingtime] set color green
       allocate-caregivers ]]
;; Note the nesting of the same function within each IF statement. This means process iterates until all caregivers are allocated or no patients are waiting, thus ensuring all caregivers are allocated
end



;; Allocate Minor Caregivers

to allocate-minorcaregivers
Ask minorcaregivers [if count out-link-neighbors > 0 [set minorcaregiver_available 0]]   ;; If you have a link to a neighbour, mark yourself unavailable
Ask minorcaregivers [if count out-link-neighbors = 0 [set minorcaregiver_available 1]]   ;; If you don't have any links, mark yourself available
Ask patients [if count in-link-neighbors > 0 [set pt_allocated_caregiver 1]]  ;; If you do have a linked caregiver, mark yourself allocated
Ask patients [if count in-link-neighbors = 0 [set pt_allocated_caregiver 0]]  ;; If you don't have any links to a caregiver, mark youself unallocated
IF count patients with [pt_allocated_caregiver = 0] = 0 [stop]  ;; Stop if there are no patients reporting no caregiver
IF count minorcaregivers with [minorcaregiver_available = 1] = 0 [stop]   ;; Stop if there are no caregivers reporting themselves available

IF count patients with [pt_allocated_caregiver = 0 AND pt_location = 21] > 0
     [ask one-of minorcaregivers with [minorcaregiver_available = 1]
         [create-link-to max-one-of patients with [pt_location = 21 AND pt_allocated_caregiver = 0][pt_waitingtime] set color green
       allocate-minorcaregivers ]]

end

;; ==============
;; Treat Patients
;; ==============

to treat-patients
ask patients [if count in-link-neighbors > 0 [set pt_allocated_caregiver 1]]

;; Severity 1 : death probability, cant happen

;; Severity 2 : death probability
set death_prob (random 5000)
ask patients with [pt_allocated_caregiver = 1 and pt_severity = 2] [
    IF death_prob <= 1 [
      ask one-of patients with [pt_allocated_caregiver = 1 and pt_severity = 2] [set pt_location 101 set pt_allocated_caregiver 0]
  ]
]

;; Severity 3 - death probability
set death_prob (random 1000)
ask patients with [pt_allocated_caregiver = 1 and pt_severity = 3] [
    IF death_prob <= 1 [
      ask one-of patients with [pt_allocated_caregiver = 1 and pt_severity = 3] [set pt_location 101 set pt_allocated_caregiver 0]
  ]
]

ask patients with [pt_allocated_caregiver = 1 AND pt_location != 101][set pt_treatment_time pt_treatment_time - 1]
end

;; ==================
;; Discharge Patients
;; ==================

to discharge-patients
ask patients with [pt_treatment_time < 1 AND (PT_LOCATION = 22 OR PT_LOCATION = 21 OR PT_LOCATION = 23)]
      [set pt_location 91
       ask my-in-links [ask end1 [setxy -5 12 set color blue]
         ask end2 [setxy 16 16 hide-turtle]
         die]
       ]

ask patients with [pt_location = 101]
      [
       ask my-in-links [ask end1 [setxy -5 12 set color blue]
         ask end2 [setxy 16 16 hide-turtle]
         die]
       ]
;; Moves patients who have completed treatment to discharged and deletes their link to a caregiver
end

to calculate-variables
IFELSE count patients with [pt_location = 11] = 0 [set waittime_ambulance_avg 0 set waittime_ambulance_max 0]
                                                  [set waittime_ambulance_avg (sum [pt_waitingtime] of patients with [pt_location = 11] / count patients with [pt_location = 11])
                                                   set waittime_ambulance_max (max [pt_waitingtime] of patients with [pt_location = 11])
                                                   set waittime_ambulance_avg waittime_ambulance_avg - 6
                                                   set waittime_ambulance_max waittime_ambulance_max - 6]

IFELSE count patients with [pt_location = 12] = 0 [set waittime_waitroom_avg 0 set waittime_waitroom_avg 0]
                                                  [set waittime_waitroom_avg (sum [pt_waitingtime] of patients with [pt_location = 12] / count patients with [pt_location = 12])
                                                   set waittime_waitroom_max (sum [pt_waitingtime] of patients with [pt_location = 12])]

IFELSE count patients with [pt_location = 91] = 0 [set total_waittime_avg 0 set total_waittime_max 0]
                                                  [set total_waittime_avg (sum [pt_waitingtime] of patients with [pt_location = 91] / count patients with [pt_location = 91])
                                                   set total_waittime_max (max [pt_waitingtime] of patients with [pt_location = 91])]
end
@#$#@#$#@
GRAPHICS-WINDOW
814
14
1251
452
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
33
210
205
243
Step 1: Setup Simulation
Setup
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
28
272
201
353
Step 2: Go Simulation
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
497
203
807
248
Waiting Room Patients (Location 12)
count patients with [pt_location = 12]
17
1
11

MONITOR
215
203
493
248
Ambulance Patients Waiting (Location 11)
count patients with [pt_location = 11]
17
1
11

MONITOR
467
479
576
524
Minors (21)
count patients with [pt_location = 21]
17
1
11

MONITOR
583
479
692
524
Majors (22)
count patients with [pt_location = 22]
17
1
11

MONITOR
699
479
808
524
Resus (23)
count patients with [pt_location = 23]
17
1
11

PLOT
215
15
807
199
Patients Waiting
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Ambulance Wait" 1.0 0 -955883 true "" "plot count patients with [pt_location = 11]"
"Waiting Room" 1.0 0 -8732573 true "" "plot count patients with [pt_location = 12]"

SLIDER
34
15
206
48
caregivers_number
caregivers_number
0
20
6.0
1
1
NIL
HORIZONTAL

PLOT
218
305
808
473
Treatment Units Usage
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Resus" 1.0 0 -8053223 true "" "plot count patients with [pt_location = 23]"
"Majors" 1.0 0 -3844592 true "" "plot count patients with [pt_location = 22]"
"Minors" 1.0 0 -13210332 true "" "plot count patients with [pt_location = 21]"

SLIDER
34
91
206
124
minor_size_slider
minor_size_slider
0
12
8.0
1
1
NIL
HORIZONTAL

SLIDER
34
129
206
162
major_size_slider
major_size_slider
0
10
7.0
1
1
NIL
HORIZONTAL

SLIDER
34
167
206
200
resus_size_slider
resus_size_slider
0
8
4.0
1
1
NIL
HORIZONTAL

SLIDER
28
53
207
86
minorcaregivers_number
minorcaregivers_number
0
10
6.0
1
1
NIL
HORIZONTAL

MONITOR
216
252
352
297
Average Wait (ticks)
round waittime_ambulance_avg
17
1
11

MONITOR
356
252
504
297
Max Current Wait (ticks)
waittime_ambulance_max
17
1
11

MONITOR
498
252
654
297
Average Wait (ticks)
round waittime_waitroom_avg
17
1
11

MONITOR
658
252
808
297
Max Current Wait (ticks)
waittime_waitroom_max
17
1
11

MONITOR
219
480
342
525
Discharged Patients
count patients with [pt_location = 91]
17
1
11

MONITOR
219
530
335
575
Dead Patients - S2
count patients with [pt_location = 101 and pt_severity = 2]
17
1
11

MONITOR
218
582
334
627
Dead Patients - S3
count patients with [pt_location = 101 and pt_severity = 3]
17
1
11

INPUTBOX
23
394
161
454
timeStop
143.0
1
0
Number

@#$#@#$#@
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

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

wolf
false
0
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
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
