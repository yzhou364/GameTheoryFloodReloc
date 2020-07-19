extensions [csv gis]
breed [ poors poor ]
breed [ normals normal ]
globals
[
  ;; user's settings
  FLOOD_HEIGHT_10Y FLOOD_HEIGHT_100Y MHHW MSL

  ;; model's settings
  ; flood lists
  PROB_10Y_LIST PROB_100Y_LIST PROB_LIST
  ; gov's monetary coefficient  lists
  PAST_LOSS SUBSIDY_PV SUBSIDY_HYPERBOLIC
  ; gov's monetary value
  OBJECTIVE
  ; resident's coefficient monetary lists
  TOTAL OPP_COST
  ; Miscellaneous
  MOTIVATED counter_move counter_notmove counter_normalmove counter_poormove counter_normalinf counter_poorinf

  ;; Miscellaneous list
  TIME GEODATASET CLASS SUM_SUBSIDY MOVE_REACHED? NEW_SUBSIDY ORDER_SUB PERCENTILE REM UB LB SUBSIDY
]

turtles-own
[
  ;; House properties
  Total_market_value Structure_Value Sq.ft. Damage_pct_10Y Damage_pct_100Y Cost_to_personal_property_10Y Cost_to_personal_property_100Y
  Latitude Longitude Elevation Stories Basement Inundation_10Y Inundation_100Y
  ;; Monetary
  Future_loss Future_benefit
  ;; Moving
  Mot_year Ori_year Ori_moved? nearhouse move normal_inf? poor_inf? S_prime Moved? cnear nbpast_move
]

to Clear
  clear-all
end

to Setup
  clear-all

  ;random-seed 10000000
  Initialize_list
  Input_10Y_flood_data
  Input_100Y_flood_data
  Input_Multiple ;; Calculate multiple flood
  Update_coefficient_TOTAL  ;; Update values and coefficient in each tick
  Update_coefficient_SUBSIDY_PV
  set FLOOD_HEIGHT_10Y Flood_Height_Meters_10Y
  set FLOOD_HEIGHT_100Y Flood_Height_Meters_100Y
  set MHHW MHHW_Meters
  set MSL MSL_Meters
  set TIME 0
  ;set GEODATASET gis:load-dataset "data/Export_Output_2.shp"
  set GEODATASET gis:load-dataset "data/NY11234-11236.shp"
  ; Set the world envelope to the union of all of our dataset's envelopes
  gis:set-world-envelope (gis:envelope-union-of (gis:envelope-of GEODATASET))
  ; show gis:envelope-of GEODATASET
  House_property
  set SUBSIDY Initial_Subsidy
;  set SUM_SUBSIDY 0
  reset-ticks
end

to Go
  ;; stop condition is that every agent has moved
  if TIME > 100 [ stop ]

  Update_coefficient_TOTAL      ;; update values and coefficient in each tick
  ;Update_coefficient_SUBSIDY_PV ;; update subsidy pv value
  Update_coefficient_PAST       ;; update past loss
  set SUM_SUBSIDY []
  set ADJUSTED_SUBSIDY SUBSIDY
  ask turtles
  [
    Update_coefficient_SUBSIDY_PV_Dynamic
    Update_values    ;; update values for every agent
    Ori_change_color ;; change color if agents original moved in this year
    Change_color     ;; change color if agents moved in this year
    Influence        ;; moved influence by neighbors
    set nbpast_move 0
;    set nbpast_move move
    show Subsidy

  ]
;  show SUM_SUBSIDY
;  show OBJECTIVE
;  show NEW_SUBSIDY
;  show ORDER_SUB
;  show PERCENTILE
;  show REM



  set MOVE_REACHED? false
  set MOTIVATED count (turtles with [Mot_year != Ori_year])
  set TIME TIME + 1  ;; add time

;  set counter_move count (turtles with [Moved? = true])
;  set counter_notmove count (turtles with [Moved? = false])
;  ask turtles
;  [ (if breed = normals [
;    set counter_normalmove count (normals with [Moved? = true])
;    set counter_normalinf count (normals with [Mot_year != Ori_year])
;    ])
;    (if breed = poors [
;    set counter_poormove count (poors with [Moved? = true])
;    set counter_poorinf count (poors with [Mot_year != Ori_year])
;      ])
;  ]
  tick

end

to Update_coefficient_SUBSIDY_PV_Dynamic
  ifelse Dynamic_Subsidy?
  [
    subsidy_calculation
    (ifelse
    Dynamic_Subsidy_Trigger = "Year"
    [
        if (TIME >= Renewal_Year) and (TIME mod Renewal_Year = 0) [ set Subsidy NEW_SUBSIDY ]
        Update_coefficient_SUBSIDY_PV
    ]

    Dynamic_Subsidy_Trigger = "Percentage_Past_Moved"
    [
        if MOVE_REACHED? = false
        [
          if count (turtles with [Moved? = true]) / count turtles >= Past_Moved_Rate
          [
            set Subsidy NEW_SUBSIDY
            set MOVE_REACHED? true
          ]
        ]
        Update_coefficient_SUBSIDY_PV
    ])
  ]

  ;; when Dynamic_Subsidy? is off
  [
    Update_coefficient_SUBSIDY_PV
  ]
end

to subsidy_calculation
  if length SUM_SUBSIDY = 0 [set NEW_SUBSIDY 0 ]
  if length SUM_SUBSIDY = 1 [set NEW_SUBSIDY item 0 SUM_SUBSIDY ]
  if length SUM_SUBSIDY > 1
  [
  set ORDER_SUB sort SUM_SUBSIDY
  set PERCENTILE New_Target_Moved_Rate * (length SUM_SUBSIDY + 1)
  set REM remainder PERCENTILE 1
  ;;upper bound
    ifelse floor PERCENTILE = 0 [ set UB 1 ]
    [ set UB floor PERCENTILE ]
  ;;lower bound
    ifelse floor PERCENTILE <= 0 [ set LB 0 ]
    [ set LB (floor PERCENTILE) - 1 ]
  set new_Subsidy REM * ((item UB ORDER_SUB) - (item LB ORDER_SUB)) + item LB ORDER_SUB
  ]
end

to Influence  ;;determine relocated house influenced by their neighbors, must go along with the running years
  if breed = normals
  [
    if Moved? = false
    [
      set nearhouse min-n-of 4 other normals [distance myself] ;; neigbors = n
      set move count (nearhouse with [Moved? = true])
      if (nbpast_move < move)      ; to compare the difference of neighbor's influence
      [
        if random-float 100 <= Neighbor_Influence_Probability
        [
          set Moved? true
          set color pink
          set normal_inf? true
          set Mot_year TIME
        ]
        set nbpast_move move
      ]
    ]
  ]
  if breed = poors
  [
    if Moved? = false
    [
      set nearhouse min-n-of 4 other poors [distance myself]; set color yellow
      set move count (nearhouse with [Moved? = true])
      if (nbpast_move < move)
      [
        if random-float 100 <= Neighbor_Influence_Probability
        [
          set Moved? true
          set color pink
          set poor_inf? true
          set Mot_year TIME
        ]
        set nbpast_move move
      ]
    ]
  ]
end

to House_property
;  foreach gis:feature-list-of GEODATASET [ vector-feature ->
;    ;show vector-feature
;    let loc gis:location-of(first(first (gis:vertex-lists-of vector-feature)))
;    if not empty? loc[
;      create-turtles 1[
;      set xcor item 0 loc
;      set ycor item 1 loc
;      set Latitude gis:property-value vector-feature "LATITUDE"
;      set Longitude gis:property-value vector-feature "LONGITUDE"
;      set Elevation gis:property-value vector-feature "ALTITUDE__"
;      set Stories gis:property-value vector-feature "NOOFSTORIE"
;      set Basement gis:property-value vector-feature "STORYTYPES"
;      set Total_market_value gis:property-value vector-feature "TOTALMARKE"
;      set Structure_value gis:property-value vector-feature "IMPROVEMEN"
;      set Sq.ft. gis:property-value vector-feature "SQUAREFEET"
;      set size 5
;      set color (5 + floor (gis:property-value vector-feature "TOTALMARKE" / 200000 ) * 10)
;      ;set color (13 + floor (gis:property-value vector-feature "TOTALMARKE" / 20000 ) * 0.01)
;      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
;      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
;      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
;      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
;      Inundation_property_damage_cost
;      Setting_agents
;      ]
;    ]
;  ]


  create-turtles 6
  ask turtle 1 [
      set xcor 100
      set ycor 200
      set Elevation 1.8
      set Stories 1
      set Basement ""
      set Total_market_value 349000
      set Structure_value 245000
      set Sq.ft. 1571
      set size 25
      set color (5 + floor (Total_market_value / 200000 ) * 10)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
  ]
  ask turtle 2 [
      set xcor 50
      set ycor 50
      set Elevation 2
      set Stories 1
      set Basement ""
      set Total_market_value 333000
      set Structure_value 218000
      set Sq.ft. 1287
      set size 25
      set color (5 + floor (Total_market_value / 200000 ) * 10)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
  ]
  ask turtle 3 [
      set xcor 150
      set ycor 50
      set Elevation 5.8
      set Stories 1
      set Basement ""
      set Total_market_value 338000
      set Structure_value 219000
      set Sq.ft. 1873
      set size 25
      set color (5 + floor (Total_market_value / 200000 ) * 10)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
  ]
  ask turtle 4 [
      set xcor 150
      set ycor 250
      set Elevation 3.1
      set Stories 1
      set Basement ""
      set Total_market_value 369000
      set Structure_value 278000
      set Sq.ft. 1552
      set size 25
      set color (5 + floor (Total_market_value / 200000 ) * 10)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
  ]
  ask turtle 5 [
      set xcor 50
      set ycor 250
      set Elevation 2.5
      set Stories 1
      set Basement ""
      set Total_market_value 321000
      set Structure_value 195000
      set Sq.ft. 920
      set size 25
      set color (5 + floor (Total_market_value / 200000 ) * 10)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0 [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0 [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
  ]


end

to Setting_agents
  set S_prime 1000000000000 ;;??
  ifelse Total_market_value >= House_Price_Cutoff   ;; categorizing the economic status
  [
    set breed normals
    set shape "triangle"
    ;set color green
  ]
  [
    set breed poors
    set shape "circle"
    ;set color red
  ]
  set normal_inf? false
  set poor_inf? false
  set  Moved? false
  set  Ori_moved? false
  set  Ori_year 200
  set  Mot_year 200
  set  nbpast_move 0
  Damage_structure_pct_conditions ;; set expected loss for the future standing at year one and update at every tick
end

to Update_coefficient_PAST ;; function to calculate the coefficient of the past loss of the  government's objective
                           ;; item 0 and 3 refers to Normal, item 1 and 4 refers to Low-income and item 2 and 5 refers to government as always
  if Flood_type = "10_year"
  [
    let iter 0
    loop
    [
      if iter >= TIME [ stop ]
      set PAST_LOSS replace-item 0 PAST_LOSS ( ( item 0 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set PAST_LOSS replace-item 1 PAST_LOSS ( ( item 1 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set PAST_LOSS replace-item 2 PAST_LOSS ( ( item 2 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set iter iter + 1
    ]
  ]
  if Flood_type = "100_year"
  [
    let iter 0
    loop
    [
      if iter >= TIME [ stop ]
      set PAST_LOSS replace-item 0 PAST_LOSS ( ( item 0 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
      set PAST_LOSS replace-item 1 PAST_LOSS ( ( item 1 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
      set PAST_LOSS replace-item 2 PAST_LOSS ( ( item 2 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
      set iter iter + 1
    ]
  ]
  if Flood_type = "Multiple"
  [
    let iter 0
    loop
    [
      if iter >= TIME [ stop ]
      set PAST_LOSS replace-item 0 PAST_LOSS ( ( item 0 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_LIST ) ))
      set PAST_LOSS replace-item 1 PAST_LOSS ( ( item 1 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_LIST ) ))
      set PAST_LOSS replace-item 2 PAST_LOSS ( ( item 2 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_LIST ) ))
      set PAST_LOSS replace-item 3 PAST_LOSS ( ( item 3 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set PAST_LOSS replace-item 4 PAST_LOSS ( ( item 4 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set PAST_LOSS replace-item 5 PAST_LOSS ( ( item 5 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set iter iter + 1
    ]
  ]
end

to Update_coefficient_TOTAL ;;; I think the INDEX MIGHT BE WRONG here, so I've adjust the function
                            ;; function to calculate the coefficient of the future loss of the residents
                            ;; coefficient of expected future loss
  let iter TIME + 1  ;let iter 0
  if Hyperbolic?
  [
    if Flood_type = "10_year"
    [
      loop
      [
        if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                     ;; set different cumulative future loss

        set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
        set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
        set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
        set iter iter + 1


        ;; THIS IS the original version
        ;;; Fah's reason to change this function: since iter starts from 0 and when iter < TIME, it will give a negative value. This doesn't make sense to calculate future loss
        ;;; Moreover, it doesn't follow the calculation setup from your paper that iter starts from iter = TIME and ends at infinity(=Period, in this case).
        ;set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
        ;set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST )))
        ;set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
        ;set iter iter + 1
        ;;show TOTAL  ;; show to check calculation
      ]
    ]
    if Flood_type = "100_year"
    [
      loop
      [
        if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                     ;; set different cumulative future loss

        set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_100Y_LIST ) ))
        set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_100Y_LIST ) ))
        set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_100Y_LIST ) ))
        set iter iter + 1

        ;; THIS IS the original version
;        set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_100Y_LIST ) ))
;        set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_100Y_LIST ) ))
;        set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME  + 1) PROB_100Y_LIST ) ))
;        set iter iter + 1
        ;;show TOTAL  ;; show to check calculation
      ]
    ]
    if Flood_type = "Multiple"
    [
      loop
      [
        if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                     ;; set different cumulative future loss

        set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_LIST ) ))
        set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_LIST ) ))
        set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_LIST ) ))
        set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST ) ))
        set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST ) ))
        set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST ) ))
        set iter iter + 1

        ;; THIS IS the original version
;        set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_LIST ) ))
;        set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_LIST ) ))
;        set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_LIST ) ))
;        set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
;        set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
;        set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME  + 1 ) PROB_10Y_LIST ) ))
;        set iter iter + 1
        ;;show TOTAL  ;; show to check calculation
      ]
    ]
  ]

  ;; if not hyperbolic
  if Flood_type = "10_year"
  [
    loop
    [
      if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                   ;; set different cumulative future loss

      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis  ) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ (iter - TIME)) * ( item ( iter ) PROB_10Y_LIST )))
      set iter iter + 1

      ;; THIS IS the original version
      ;; My thoughts
      ;; the original version: iter starts at 0 and Let TIME = 5, PROB_100Y_LIST(0+5+1)/(( 1 + Normal_dis ) ^ (0)) doesn't make sense because
      ;; we calculate the coef of flood loss in the next year but didn't bring it back to the present (since ( 1 + Normal_dis ) ^ (0) = 1 )
;      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
;      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis  ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST )))
;      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
;      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "100_year"
  [
    loop
    [
      if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                   ;; set different cumulative future loss

      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ (iter - TIME) ) * ( item ( iter ) PROB_100Y_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ (iter - TIME)) * ( item ( iter ) PROB_100Y_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ (iter - TIME)) * ( item ( iter ) PROB_100Y_LIST ) ))
      set iter iter + 1

      ;; THIS IS the original version
;      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_100Y_LIST ) ))
;      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_100Y_LIST ) ))
;      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME  + 1) PROB_100Y_LIST ) ))
;      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "Multiple"
  [
    loop
    [
      if iter > period [stop] ;if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                                                   ;; set different cumulative future loss

      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ (iter - TIME)) * ( item ( iter ) PROB_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ (iter - TIME) ) * ( item ( iter ) PROB_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ (iter - TIME) ) * ( item ( iter ) PROB_LIST ) ))
      set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ (iter - TIME) ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ (iter - TIME) ) * ( item ( iter ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ (iter - TIME)) ) * ( item ( iter ) PROB_10Y_LIST ) )
      set iter iter + 1

      ;; THIS IS the original version
;      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_LIST ) ))
;      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_LIST ) ))
;      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_LIST ) ))
;      set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
;      set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
;      set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter) ) * ( item ( iter + TIME  + 1 ) PROB_10Y_LIST ) )
;      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
end

to Update_coefficient_SUBSIDY_PV ;; function to update the coefficient of a one-time subsidy

  set SUBSIDY_PV replace-item 0 SUBSIDY_PV ( Subsidy / ( 1 + Normal_dis ) ^ TIME )
  set SUBSIDY_PV replace-item 1 SUBSIDY_PV ( Subsidy / ( 1 + Poor_dis ) ^ TIME )
  set SUBSIDY_PV replace-item 2 SUBSIDY_PV ( Subsidy / ( 1 + Government_dis) ^ TIME )

end

to Update_values ;; Function to update the future loss value for each home
  if breed = normals
  [
    if Flood_type = "10_year"
    [
      set Future_loss (item 0 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y)
    ]
    if Flood_type = "100_year"
    [
      set Future_loss (item 0 TOTAL) * (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y)
    ]
    if Flood_type = "Multiple"
    [
      set Future_loss (((item 3 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y) + ((item 0 TOTAL) *  (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y))))
    ]
  ]
  if breed = poors
  [
    if Flood_type = "10_year"
    [
      set Future_loss (item 1 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2)
    ]
    if Flood_type = "100_year"
    [
      set Future_loss (item 1 TOTAL) * (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2)
    ]
    if Flood_type = "Multiple"
    [
      set Future_loss (((item 4 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2) + ((item 1 TOTAL) *  (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2 ))))
    ]
  ]
end

to Ori_change_color ;; to determine moved households without an influence of the subsidy ;; ONLY One-time-Subsidy CASE

  if breed = normals
  [
    if Government_strategy = "One-time-Subsidy"
    [
      if Total_market_value  *  Moving_Cost_Multiplier - Future_loss <= threshold
      [
        if Ori_moved? = False
        [
          set Ori_moved? True
          set Ori_year TIME
        ]
       ]
    ]
  ]

  if breed = poors
  [
    if Government_strategy = "One-time-Subsidy"
    [
      if Total_market_value  *  Moving_Cost_Multiplier - Future_loss <= threshold
      [
        if Ori_moved? = False
        [
          set Ori_moved? True
          set Ori_year TIME
        ]
      ]
    ]
  ]
end

to Change_color ;; if the moving cost minus the pv of subsidy is less than the future loss, then residents will move ;; ONLY One-time-Subsidy CASE ;;;INDEX MIGHT BE WRONG, FIXED it already
  if breed = normals
  [
    if Government_strategy = "One-time-Subsidy"
    [
      ifelse Total_market_value * Moving_Cost_Multiplier - Subsidy - Future_loss <= threshold
      [
        if Moved? = False
        [
          if Total_market_value * Moving_Cost_Multiplier - Future_loss < S_prime
          [
            set S_prime Total_market_value * Moving_Cost_Multiplier - Future_loss
          ]

        ;;; set new_move_year ticks
        set color color + 4  ;; change color to red if moved
        set Moved? True      ;; resident has moved
        set Mot_year TIME
        if Flood_type = "Multiple"
          [
            set OBJECTIVE OBJECTIVE + (item 5 PAST_LOSS)*((Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y) + (item 2 PAST_LOSS)* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y))
            set OBJECTIVE OBJECTIVE + (item 2 SUBSIDY_PV)

            ;; Original
            ;set OBJECTIVE OBJECTIVE + (item 2 PAST_LOSS)*((Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y) + (item 5 PAST_LOSS)* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y))
            ;set OBJECTIVE OBJECTIVE + (item 2 SUBSIDY_PV)
          ]
        if Flood_type = "100_year"
          [
            set OBJECTIVE OBJECTIVE + (item 2 PAST_LOSS)*(Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y)
            set OBJECTIVE OBJECTIVE + (item 2 SUBSIDY_PV)
          ]
        if Flood_type = "10_year"
          [
            set OBJECTIVE OBJECTIVE + (item 2 PAST_LOSS)*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y)
            set OBJECTIVE OBJECTIVE + (item 2 SUBSIDY_PV)
          ]
        ]
      ]
      ;; else
      [if Moved? = False [ set SUM_SUBSIDY lput (Total_market_value * Moving_Cost_Multiplier - Future_loss) SUM_SUBSIDY]
      ]
    ]
  ]

  if breed = poors
  [
    if Government_strategy = "One-time-Subsidy"
    [
      ifelse Total_market_value * Moving_Cost_Multiplier - Subsidy - Future_loss <= threshold
      [ ;set SUM_SUBSIDY insert-item 0 SUM_SUBSIDY (Total_market_value * Moving_Cost_Multiplier - Future_loss)

        if moved? = False
        [
         if Total_market_value * Moving_Cost_Multiplier - Future_loss < S_prime
          [
            set S_prime Total_market_value * Moving_Cost_Multiplier - Future_loss
          ]

        set color color + 4  ;; change color to red if moved
        set moved? True      ;; resident has moved
        set Mot_year TIME
        if Flood_type = "Multiple"
          [
            set OBJECTIVE OBJECTIVE +  ((item 5 PAST_LOSS)*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2) + (item 2 PAST_LOSS)* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2))
            set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV)

            ;; ORIGINAL
            ;set OBJECTIVE OBJECTIVE +  ((item 2 PAST_LOSS)*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2) + (item 5 PAST_LOSS)* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2))
            ;set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV)
          ]
        if Flood_type = "100_year"
          [
            set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2)
            set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV)
          ]
        if Flood_type = "10_year"
          [
            set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2)
            set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV)
          ]
       ]
      ]
      ;set subsidy-needed Total_market_value * Moving_Cost_Multiplier - Future_loss
      ;;else
      ;[if Moved? = False [ set SUM_SUBSIDY insert-item 0 SUM_SUBSIDY (Total_market_value * Moving_Cost_Multiplier - Future_loss)]
      [if Moved? = False [ set SUM_SUBSIDY lput (Total_market_value * Moving_Cost_Multiplier - Future_loss) SUM_SUBSIDY]
      ]
    ]
  ]
end

to Input_10Y_flood_data ;; A 10-year flood probability data
  set PROB_10Y_LIST [ 0 ]
  file-close
  file-open "data/10_NY_4.5.csv"
  loop
  [
    ifelse file-at-end? [ stop ]
    [
      set PROB_10Y_LIST lput file-read PROB_10Y_LIST
    ]
  ]
  file-close
end

to Input_100Y_flood_data ;; A 100-year flood probability data
  set PROB_100Y_LIST [ 0 ]
  file-close
  file-open "data/100_NY_4.5.csv"
  loop
  [
    ifelse file-at-end? [ stop ]
    [
      set PROB_100Y_LIST lput file-read PROB_100Y_LIST
    ]
  ]
  file-close
end

to Input_Multiple ;; a flood probability data between 10-year and 100-year flood ??
  set PROB_LIST [ 0 ]
  let iter 0
  let len length PROB_10Y_LIST
  loop
  [
    ifelse iter >= len [ stop ]
    [
      set PROB_LIST lput (( item iter PROB_10Y_LIST) - (item iter PROB_100Y_LIST)) PROB_LIST
      set iter iter + 1
    ]
  ]
end

to Hide_moved
  ;set MOTIVATED count (turtles with [Mot_year != Ori_year])
  set hidden? True
  if Mot_year != Ori_year
  [
    set hidden? False
    set size 15
  ]
end

to write_data
  export-world "Fah_world.csv"
end

to Initialize_list
  set SUBSIDY_PV [] ;; a list for gov's objective function
  set TOTAL []      ;; a list of residents future loss
  set PAST_LOSS []  ;; a list for gov's objective function
  set SUBSIDY_HYPERBOLIC []
  set OPP_COST []
;  set SUM_SUBSIDY []
  let iter 0
  set CLASS 6
  loop [
    if iter > CLASS [ stop ]
    set SUBSIDY_PV lput 0 SUBSIDY_PV
    set TOTAL lput 0 TOTAL
    set PAST_LOSS lput 0 PAST_LOSS
    set OPP_COST lput 0 OPP_COST
    ;set SUM_SUBSIDY lput 0 SUM_SUBSIDY
    ;set SUBSIDY_HYPERBOLIC lput 0 SUBSIDY_HYPERBOLIC
    set iter iter + 1
  ]
end

to Inundation_property_damage_cost
  set Cost_to_personal_property_10Y 0
  (ifelse
  Inundation_10Y <= 0 [ set Cost_to_personal_property_10Y 0 ]
  Inundation_10Y <= 2 [ set Cost_to_personal_property_10Y 3172 ]
  Inundation_10Y <= 3 [ set Cost_to_personal_property_10Y 4917 ]
  Inundation_10Y <= 4 [ set Cost_to_personal_property_10Y 7207 ]
  Inundation_10Y <= 5 [ set Cost_to_personal_property_10Y 13914 ]
  Inundation_10Y <= 6 [ set Cost_to_personal_property_10Y 14777 ]
  Inundation_10Y <= 7 [ set Cost_to_personal_property_10Y 17700 ]
  Inundation_10Y <= 8 [ set Cost_to_personal_property_10Y 20624 ]
  Inundation_10Y <= 9 [ set Cost_to_personal_property_10Y 23547 ]
  Inundation_10Y <= 10 [ set Cost_to_personal_property_10Y 26470 ]
  Inundation_10Y <= 11 [ set Cost_to_personal_property_10Y 29394 ]
  Inundation_10Y <= 12 [ set Cost_to_personal_property_10Y 32317 ]
  Inundation_10Y <= 24 [ set Cost_to_personal_property_10Y 43001 ]
  Inundation_10Y <= 36 [ set Cost_to_personal_property_10Y 46633 ]
  Inundation_10Y > 36 [set Cost_to_personal_property_10Y 50000])

  set Cost_to_personal_property_100Y 0
  (ifelse
  Inundation_100Y <= 0 [ set Cost_to_personal_property_100Y 0 ]
  Inundation_100Y <= 2 [ set Cost_to_personal_property_100Y 3172]
  Inundation_100Y <= 3 [ set Cost_to_personal_property_100Y 4917]
  Inundation_100Y <= 4 [ set Cost_to_personal_property_100Y 7207]
  Inundation_100Y <= 5 [ set Cost_to_personal_property_100Y 13914]
  Inundation_100Y <= 6 [ set Cost_to_personal_property_100Y 14777]
  Inundation_100Y <= 7 [ set Cost_to_personal_property_100Y 17700]
  Inundation_100Y <= 8 [ set Cost_to_personal_property_100Y 20624]
  Inundation_100Y <= 9 [ set Cost_to_personal_property_100Y 23547]
  Inundation_100Y <= 10 [ set Cost_to_personal_property_100Y 26470]
  Inundation_100Y <= 11 [ set Cost_to_personal_property_100Y 29394]
  Inundation_100Y <= 12 [ set Cost_to_personal_property_100Y 32317]
  Inundation_100Y <= 24 [ set Cost_to_personal_property_100Y 43001]
  Inundation_100Y <= 36 [ set Cost_to_personal_property_100Y 46633]
  Inundation_100Y > 36 [set Cost_to_personal_property_100Y 50000])
end

to Damage_structure_pct_conditions
  (ifelse
  Stories = 1 and Basement = "" [ Damage_percentage_onestory_nobasement ]
  Stories != 1 and Basement = "" [ Damage_percentage_morethanonestory_nobasement ]
  Stories = 1 and Basement != "" [ Damage_percentage_onestory_basement ]
  Stories != 1 and Basement != "" [ Damage_percentage_morethanonestory_basement ])
end

to Damage_percentage_onestory_nobasement
  set Damage_pct_10Y 0
  (ifelse
  Inundation_10Y <= 0 [set Damage_pct_10Y 0]
  Inundation_10Y <= 1 [set Damage_pct_10Y 0.233]
  Inundation_10Y <= 2 [set Damage_pct_10Y 0.321]
  Inundation_10Y <= 3 [set Damage_pct_10Y 0.401]
  Inundation_10Y <= 4 [set Damage_pct_10Y 0.471]
  Inundation_10Y <= 5 [set Damage_pct_10Y 0.532]
  Inundation_10Y <= 6 [set Damage_pct_10Y 0.586]
  Inundation_10Y <= 7 [set Damage_pct_10Y 0.632]
  Inundation_10Y <= 8 [set Damage_pct_10Y 0.672]
  Inundation_10Y <= 9 [set Damage_pct_10Y 0.705]
  Inundation_10Y <= 10 [set Damage_pct_10Y 0.732]
  Inundation_10Y > 10 [set Damage_pct_10Y 0.754]) ;Inundation > 10 consider the same high damage to the house

  set Damage_pct_100Y 0
  (ifelse
  Inundation_100Y <= 0 [set Damage_pct_100Y 0]
  Inundation_100Y <= 1 [set Damage_pct_100Y 0.233]
  Inundation_100Y <= 2 [set Damage_pct_100Y 0.321]
  Inundation_100Y <= 3 [set Damage_pct_100Y 0.401]
  Inundation_100Y <= 4 [set Damage_pct_100Y 0.471]
  Inundation_100Y <= 5 [set Damage_pct_100Y 0.532]
  Inundation_100Y <= 6 [set Damage_pct_100Y 0.586]
  Inundation_100Y <= 7 [set Damage_pct_100Y 0.632]
  Inundation_100Y <= 8 [set Damage_pct_100Y 0.672]
  Inundation_100Y <= 9 [set Damage_pct_100Y 0.705]
  Inundation_100Y <= 10 [set Damage_pct_100Y 0.732]
  Inundation_100Y > 10 [set Damage_pct_100Y 0.754])  ;Inundation > 10 consider the same high damage to the house
end

to Damage_percentage_morethanonestory_nobasement
  set Damage_pct_10Y 0
  (ifelse
  Inundation_10Y <= 0 [set Damage_pct_10Y 0]
  Inundation_10Y <= 1 [set Damage_pct_10Y 0.152]
  Inundation_10Y <= 2 [set Damage_pct_10Y 0.209]
  Inundation_10Y <= 3 [set Damage_pct_10Y 0.263]
  Inundation_10Y <= 4 [set Damage_pct_10Y 0.314]
  Inundation_10Y <= 5 [set Damage_pct_10Y 0.362]
  Inundation_10Y <= 6 [set Damage_pct_10Y 0.407]
  Inundation_10Y <= 7 [set Damage_pct_10Y 0.449]
  Inundation_10Y <= 8 [set Damage_pct_10Y 0.488]
  Inundation_10Y <= 9 [set Damage_pct_10Y 0.524]
  Inundation_10Y <= 10 [set Damage_pct_10Y 0.557]
  Inundation_10Y > 10 [set Damage_pct_10Y 0.587]) ;Inundation > 10 consider the same high damage to the house

  set Damage_pct_100Y 0
  (ifelse
  Inundation_100Y <= 0 [set Damage_pct_100Y 0]
  Inundation_100Y <= 1 [set Damage_pct_100Y 0.152]
  Inundation_100Y <= 2 [set Damage_pct_100Y 0.209]
  Inundation_100Y <= 3 [set Damage_pct_100Y 0.263]
  Inundation_100Y <= 4 [set Damage_pct_100Y 0.314]
  Inundation_100Y <= 5 [set Damage_pct_100Y 0.362]
  Inundation_100Y <= 6 [set Damage_pct_100Y 0.407]
  Inundation_100Y <= 7 [set Damage_pct_100Y 0.449]
  Inundation_100Y <= 8 [set Damage_pct_100Y 0.488]
  Inundation_100Y <= 9 [set Damage_pct_100Y 0.524]
  Inundation_100Y <= 10 [set Damage_pct_100Y 0.557]
  Inundation_100Y > 10 [set Damage_pct_100Y 0.587]) ;Inundation > 10 consider the same high damage to the house
end

to Damage_percentage_onestory_basement
  set Damage_pct_10Y 0
  (ifelse
  Inundation_10Y <= 0 [set Damage_pct_10Y 0]
  Inundation_10Y <= 1 [set Damage_pct_10Y 0.32]
  Inundation_10Y <= 2 [set Damage_pct_10Y 0.387]
  Inundation_10Y <= 3 [set Damage_pct_10Y 0.455]
  Inundation_10Y <= 4 [set Damage_pct_10Y 0.522]
  Inundation_10Y <= 5 [set Damage_pct_10Y 0.586]
  Inundation_10Y <= 6 [set Damage_pct_10Y 0.645]
  Inundation_10Y <= 7 [set Damage_pct_10Y 0.698]
  Inundation_10Y <= 8 [set Damage_pct_10Y 0.742]
  Inundation_10Y <= 9 [set Damage_pct_10Y 0.777]
  Inundation_10Y <= 10 [set Damage_pct_10Y 0.801]
  Inundation_10Y > 10 [set Damage_pct_10Y 0.811]) ;Inundation > 10 consider the same high damage to the house

  set Damage_pct_100Y 0
  (ifelse
  Inundation_100Y <= 0 [set Damage_pct_100Y 0]
  Inundation_100Y <= 1 [set Damage_pct_100Y 0.32]
  Inundation_100Y <= 2 [set Damage_pct_100Y 0.387]
  Inundation_100Y <= 3 [set Damage_pct_100Y 0.455]
  Inundation_100Y <= 4 [set Damage_pct_100Y 0.522]
  Inundation_100Y <= 5 [set Damage_pct_100Y 0.586]
  Inundation_100Y <= 6 [set Damage_pct_100Y 0.645]
  Inundation_100Y <= 7 [set Damage_pct_100Y 0.698]
  Inundation_100Y <= 8 [set Damage_pct_100Y 0.742]
  Inundation_100Y <= 9 [set Damage_pct_100Y 0.777]
  Inundation_100Y <= 10 [set Damage_pct_100Y 0.801]
  Inundation_100Y > 10 [set Damage_pct_100Y 0.811]) ;Inundation > 10 consider the same high damage to the house
end

to Damage_percentage_morethanonestory_basement
  set Damage_pct_10Y 0
  (ifelse
  Inundation_10Y <= 0 [set Damage_pct_10Y 0]
  Inundation_10Y <= 1 [set Damage_pct_10Y 0.223]
  Inundation_10Y <= 2 [set Damage_pct_10Y 0.270]
  Inundation_10Y <= 3 [set Damage_pct_10Y 0.319]
  Inundation_10Y <= 4 [set Damage_pct_10Y 0.369]
  Inundation_10Y <= 5 [set Damage_pct_10Y 0.419]
  Inundation_10Y <= 6 [set Damage_pct_10Y 0.469]
  Inundation_10Y <= 7 [set Damage_pct_10Y 0.518]
  Inundation_10Y <= 8 [set Damage_pct_10Y 0.564]
  Inundation_10Y <= 9 [set Damage_pct_10Y 0.608]
  Inundation_10Y <= 10 [set Damage_pct_10Y 0.648]
  Inundation_10Y > 10 [set Damage_pct_10Y 0.684]) ;Inundation > 10 consider the same high damage to the house

  set Damage_pct_100Y 0
  (ifelse
  Inundation_100Y <= 0 [set Damage_pct_100Y 0]
  Inundation_100Y <= 1 [set Damage_pct_100Y 0.223]
  Inundation_100Y <= 2 [set Damage_pct_100Y 0.270]
  Inundation_100Y <= 3 [set Damage_pct_100Y 0.319]
  Inundation_100Y <= 4 [set Damage_pct_100Y 0.369]
  Inundation_100Y <= 5 [set Damage_pct_100Y 0.419]
  Inundation_100Y <= 6 [set Damage_pct_100Y 0.469]
  Inundation_100Y <= 7 [set Damage_pct_100Y 0.518]
  Inundation_100Y <= 8 [set Damage_pct_100Y 0.564]
  Inundation_100Y <= 9 [set Damage_pct_100Y 0.608]
  Inundation_100Y <= 10 [set Damage_pct_100Y 0.648]
  Inundation_100Y > 10 [set Damage_pct_100Y 0.684]) ;Inundation > 10 consider the same high damage to the house
end
@#$#@#$#@
GRAPHICS-WINDOW
546
10
951
416
-1
-1
0.01
1
10
1
1
1
0
1
1
1
-1000
0
0
1000
0
0
1
ticks
60.0

BUTTON
11
26
75
59
NIL
Clear
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
96
27
162
60
NIL
setup\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

INPUTBOX
13
85
162
145
Flood_Height_Meters_100Y
1.84
1
0
Number

INPUTBOX
13
146
162
206
Flood_Height_Meters_10Y
1.11
1
0
Number

INPUTBOX
13
206
162
266
MHHW_Meters
2.543
1
0
Number

INPUTBOX
13
266
162
326
MSL_Meters
1.785
1
0
Number

SWITCH
166
205
339
238
Hyperbolic?
Hyperbolic?
0
1
-1000

CHOOSER
168
86
341
131
Flood_type
Flood_type
"100_year" "10_year" "Multiple"
0

SLIDER
351
175
523
208
Period
Period
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
167
286
339
319
Normal_dis
Normal_dis
0
1
0.09
0.01
1
NIL
HORIZONTAL

SLIDER
166
238
339
271
Hyperbolic_rate
Hyperbolic_rate
0
1
0.12
0.01
1
NIL
HORIZONTAL

SLIDER
167
319
339
352
Poor_dis
Poor_dis
0
1
0.18
0.01
1
NIL
HORIZONTAL

SLIDER
167
351
339
384
Government_dis
Government_dis
0
1
0.04
0.001
1
NIL
HORIZONTAL

SLIDER
354
268
528
301
Initial_Subsidy
Initial_Subsidy
0
1000000
515700.0
100
1
NIL
HORIZONTAL

CHOOSER
167
132
341
177
Government_Strategy
Government_Strategy
"One-time-Subsidy" "Fixed-Benefits"
0

INPUTBOX
13
340
162
400
Moving_Cost_Multiplier
2.7
1
0
Number

SLIDER
352
221
524
254
Threshold
Threshold
0
10000
0.0
1
1
NIL
HORIZONTAL

INPUTBOX
13
400
162
460
House_Price_Cutoff
389000.0
1
0
Number

BUTTON
385
29
493
62
NIL
Hide_moved
NIL
1
T
TURTLE
NIL
NIL
NIL
NIL
1

BUTTON
266
28
361
61
NIL
write_data
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
180
28
243
61
NIL
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

CHOOSER
358
86
525
131
Location
Location
"NY"
0

SLIDER
353
315
525
348
Fix_benefit
Fix_benefit
0
10000
0.0
1
1
NIL
HORIZONTAL

PLOT
23
763
223
913
Number of moved
Time
Number
0.0
100.0
0.0
6000.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [ moved?]"

PLOT
253
764
453
914
Normal move pct
Time
pct
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count normals with[moved?] / count normals"

PLOT
488
763
688
913
Low_income move pct
Time
Pct
0.0
100.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count poors with[moved?] / count poors"

PLOT
12
473
212
623
Objective
Time
Objective
0.0
100.0
0.0
10000.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot OBJECTIVE"

PLOT
242
471
779
748
Moved by Influence (Pink = Normal, Green = Poor)
Time
House Moved by Influence
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -4699768 true "" "plot count turtles with [normal_inf? = true]"
"pen-1" 1.0 0 -14439633 true "" "plot count turtles with [poor_inf? = true]"

SLIDER
168
427
426
460
Neighbor_Influence_Probability
Neighbor_Influence_Probability
0
100
0.0
1
1
%
HORIZONTAL

TEXTBOX
978
14
1128
32
Dynamic Subsidy
11
0.0
1

SWITCH
979
47
1150
80
Dynamic_Subsidy?
Dynamic_Subsidy?
0
1
-1000

CHOOSER
979
105
1175
150
Dynamic_Subsidy_Trigger
Dynamic_Subsidy_Trigger
"Year" "Percentage_Past_Moved"
0

SLIDER
979
169
1151
202
Renewal_Year
Renewal_Year
0
100
10.0
5
1
NIL
HORIZONTAL

SLIDER
979
225
1180
258
Past_Moved_Rate
Past_Moved_Rate
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
979
310
1185
343
New_Target_Moved_Rate
New_Target_Moved_Rate
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
979
362
1266
395
ADJUSTED_SUBSIDY
ADJUSTED_SUBSIDY
0
1000000
0.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This model was built to demonstrate the effects of 10-year, 100-year, and multiple inundation flood plain on a number of households who moved, and govenment objective function based on different variables given to the model.

## HOW IT WORKS

This model imports CSV file to take data about the housing information. Also it loads GIS dataset to locate the relative location on the interface.

## HOW TO USE IT

Select the location, flood type, government strategy, then click setup to loads the housign data into the model. Click run to see how each household makes decision based on the default variables. Make any adjustments to the variables, for example increased subsidy, to see different results.  

## THINGS TO NOTICE

This model only show selected zipcodes for studied states. 

Normal-income households represent by triangle turtles
Poor-income households represent by circle turtles
Furthermore, each household will be color-coded based on the range of its house price. These ranges can be adjusted.

House Price Cutoff is the variable (house price) that will differentiate normal-income household from low-income household. This variable is currently done manually by inspecting the real data.

Hide Moved will make any turtle whose motivated moving year the same as its' orginal moving year. ?????? 

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

# MODEL EXPLANATIONS

### SETUP
This function loads the data by calling other functions into the interface, sets the global variables from the inputs, and presents the house at a location based on the GIS map.

### Go
For each TIME (year), each household will be updated with its' past loss, future loss, and subsidy in terms of present value until the household decides to move or it reaches year 100th.

### House property
This function called by Setup. It will set data to each turtle. Meters of innundation will be calulated from input data, then will be converted to inches. 

### Setting agents
Dividing turtles into low-income and normal-income breed. Initializing the turtles to be not moved. Also assigning damage percentage by calling other functions.

### Update coefficient past
To calculate past loss using a loop logic (for govenment's objective function). For each TIME period, the loop will end when calculating the past loss up to one year before. For example, we are at year 5, the past will be calculate from year 0 to 4.   

### Update_coefficient_TOTAL
To calculate future loss using a loop logic (for household's decision). For each TIME period, the loop will end when calculating the future loss from the next year until the end of the period(100). For example, we are at year 5, the future will be calculate from year 6 to 100.

### Update_coefficient_SUBSIDY_PV 
This function calculate present value of subsidy for low-income, normal-income,and government in every year, then place the values in a list. 

### Update_values
This function updates future loss for the turtles who do not move. For low-income, the cost to personal property is set to be half of the normal-income for the purposeod this study.

### Ori_change_color
To determine when household choose to move without an influence of a subsidy. Decision to move is considered when the expected future loss is higher than the moving cost (total market value multiplies coving cost multiplier).

### Change_color
*This model only built with One-time-Subsidy as a government strategy.
This function will distinguish which house decides to move by changing to a lighter color when a future loss is higher than the cost of moving minus the subsidy. Furthermore, it shows the moved year of each house, and the objective value of the government.
Sprime??  

### Input_10Y_flood_data and Input_100Y_flood_data
These two functions are similar. They load the flood probability and put them into a list. 

### Input_Multiple
The flood probability is calculated by taking out 10-year from 100-year flood probability before creating a list. This step will avoid double counting two flood probabilities. ??

To avoid double counting the 10-year and 100-year flood probabilities, this function create a new flood probability list from a difference between 10-year and 100-year flood data.

### Hide_moved
Hide Moved will make any turtle whose motivated moving year the same as its' orginal moving year. ??????

### Initialize_list
This function initializes lists by setting to an empthy list. The lists are as the following:
SUBSIDY_PV : present value of Subsidy for the government's objective calculation
TOTAL : total future loss for resident's calculation
PAST_LOSS : past loss for the government's objective calculation
SUBSIDY_HYPERBOLIC : tbd

### Inundation_property_damage_cost
 This if-function assign cost to personal property to each turtle based on its' inundation level and type of flood.

### Damage_structure_pct_conditions
A connecting function that type of houses to the corresponding damage percentage.

### Damage_percentage
Assigning damage percentage to the turtles based on the previous called "Damage_structure_pct_conditions" function.


## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

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
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

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
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="Location">
      <value value="&quot;NY&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Subsidy">
      <value value="50000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hyperbolic?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Poor_dis">
      <value value="0.18"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Hyperbolic_rate">
      <value value="0.12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Government_dis">
      <value value="0.04"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Government_Strategy">
      <value value="&quot;One-time-Subsidy&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Flood_Height_Meters_100Y">
      <value value="1.84"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Normal_dis">
      <value value="0.09"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Neighbor_Influence_Probability">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="House_Price_Cutoff">
      <value value="389000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Period">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Flood_Height_Meters_10Y">
      <value value="1.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Threshold">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MHHW_Meters">
      <value value="2.543"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Moving_Cost_Multiplier">
      <value value="2.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Fix_benefit">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Flood_type">
      <value value="&quot;10_year&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MSL_Meters">
      <value value="1.785"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
