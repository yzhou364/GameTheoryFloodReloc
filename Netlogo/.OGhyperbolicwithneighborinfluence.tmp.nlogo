extensions [csv gis]
breed [ poors poor ] ;; Set different breed
breed [ normals normal ]
globals[
  GEODATASET
  FLOOD_HEIGHT_10Y
  FLOOD_HEIGHT_100Y
  MHHW
  MSL
  TIME
  TOTAL  ;; Total future loss
  PROB_10Y_LIST
  PROB_100Y_LIST
  PROB_LIST
  PAST_LOSS
  SUBSIDY_PV ;; The present value of given subsidy
  CLASS
  OBJECTIVE ;; The global objective function
  MOTIVATED ;; Number of people motivated by policy
  SUBSIDY_HYPERBOLIC
]
turtles-own[
  Latitude
  Longitude
  Elevation
  Stories
  Basement
  Total_market_value
  Structure_Value
  Sq.ft.
  Inundation_10Y
  Inundation_100Y
  Cost_to_personal_property_10Y
  Cost_to_personal_property_100Y
  Future_loss
  Future_benefit
  Damage_pct_10Y
  Damage_pct_100Y
  Moved?
  Mot_year
  Ori_moved?
  Ori_year
  nearhouse
  cnear
  move
  normal_inf?
  poor_inf?
  S_prime
]
to Clear
  clear-all
end
to Setup
  clear-all

  Initialize_list ;; Initilize lists
  Input_10Y_flood_data ;; Input data from data.csv
  Input_100Y_flood_data ;; Input data from data.csv
  Input_Mulitple ;; Calculate multiple flood
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
  reset-ticks
end
to Go
  ;; stop condition is that every agent has moved
  if TIME > 100 [
    stop
  ]

  Update_coefficient_TOTAL  ;; update values and coefficient in each tick
  Update_coefficient_SUBSIDY_PV ;; update subsidy pv value
  Update_coefficient_PAST ;; update past loss

  ask turtles [
    Update_values   ;; update values for every agent
    Ori_change_color ;; change color if agents original moved in this year
    Change_color ;; change color if agents moved in this year
    Influence
  ]
;  ask normals [
;    set normal_inf? false
;  ]
;  ask poors [
;    set poor_inf? false
;  ]

  set MOTIVATED count (turtles with [Mot_year != Ori_year])
  set TIME TIME + 1 ;; add time
  tick

end

;to influence1
;  if breed = normals
;  [
;    set nearhouse min-n-of 5 normals [distance myself]
;    ask nearhouse [
;        set size 30
;      ]
;    ;set move count (nearhouse with [Moved? = true])
;  ]
;
;end


to Influence  ;;must go along with the running years
  ;tick
  if breed = normals
  ;ask normals
  [
;;    set normal_inf? false
    if Moved? = false

    [
      ;set shape "circle"
      set nearhouse min-n-of 10 normals [distance myself]  ;; 4 neigbors
      ;ask nearhouse [
        ;set color white
      ;]
      set move count (nearhouse with [Moved? = true])
      if (move >= 3)     ; must add one (to not include myself who originally did not move)
      [
        set Moved? true
        set color pink
        ;set size 30
        set normal_inf? true
        set Mot_year TIME
      ]
    ]
  ]
  if breed = poors
  ;ask poors
  [
;    set poor_inf? false
    if (Moved? = false and ori_moved? = false)
    [
      set nearhouse min-n-of 10 poors [distance myself] set color yellow
      set move count (nearhouse with [Moved? = true and ori_moved? = true])
      if (move >= 3)
      [
        set Moved? true
        set color pink
        ;set size 30
        set poor_inf? true
        set Mot_year TIME
      ]
    ]
  ]
end

to House_property
  foreach gis:feature-list-of GEODATASET [ vector-feature ->
    ;show vector-feature
    let loc gis:location-of(first(first (gis:vertex-lists-of vector-feature)))
    if not empty? loc[
      create-turtles 1[
      set xcor item 0 loc
      set ycor item 1 loc
      set Latitude gis:property-value vector-feature "LATITUDE"
      set Longitude gis:property-value vector-feature "LONGITUDE"
      set Elevation gis:property-value vector-feature "ALTITUDE__"
      set Stories gis:property-value vector-feature "NOOFSTORIE"
      set Basement gis:property-value vector-feature "STORYTYPES"
      set Total_market_value gis:property-value vector-feature "TOTALMARKE"
        set Structure_value gis:property-value vector-feature "IMPROVEMEN"
      set Sq.ft. gis:property-value vector-feature "SQUAREFEET"
      set size 5
      set color (5 + floor (gis:property-value vector-feature "TOTALMARKE" / 200000 ) * 10)
      ;set color (13 + floor (gis:property-value vector-feature "TOTALMARKE" / 20000 ) * 0.01)
      set Inundation_10Y ceiling((Flood_Height_10Y + MHHW - Elevation) * 39.3701)
      set Inundation_100Y ceiling((Flood_Height_100Y + MHHW  - Elevation) * 39.3701)
      if Inundation_10Y <= 0
        [ set Inundation_10Y 0 ]
      if Inundation_100Y <= 0
        [ set Inundation_100Y 0 ]
      Inundation_property_damage_cost
      Setting_agents
      ]
    ]
  ]
end
to Setting_agents
  set S_prime 1000000000000
  ifelse Total_market_value >= House_Price_Cutoff [
    set breed normals
    set shape "triangle"
    ;set normal_inf? false
    ;set color green
  ]
  [ set breed poors
    set shape "circle"
    ;set poor_inf? false
    ;set color red
  ]
  set normal_inf? false
  set poor_inf? false
  set  Moved? false
  set  Ori_moved? false
  set  Ori_year 200
  set  Mot_year 200
  Damage_structure_pct_conditions ;; set expected loss for the future standing at year one and update at every tick
end
to Update_coefficient_PAST
  ;; function to calcualte past loss
  ;; item 0 refers to Normal, item 1 refers to Low-income and item 2 refers to government as always
  if Flood_type = "10_year"[
  let iter 0
  loop [
    if iter >= TIME [ stop ]
    set PAST_LOSS replace-item 0 PAST_LOSS ( ( item 0 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
    set PAST_LOSS replace-item 1 PAST_LOSS ( ( item 1 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
    set PAST_LOSS replace-item 2 PAST_LOSS ( ( item 2 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_10Y_LIST ) ))
    set iter iter + 1
    ]
  ]
  if Flood_type = "100_year"[
  let iter 0
  loop [
    if iter >= TIME [ stop ]
    set PAST_LOSS replace-item 0 PAST_LOSS ( ( item 0 PAST_LOSS) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
    set PAST_LOSS replace-item 1 PAST_LOSS ( ( item 1 PAST_LOSS) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
    set PAST_LOSS replace-item 2 PAST_LOSS ( ( item 2 PAST_LOSS) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter ) PROB_100Y_LIST ) ))
    set iter iter + 1
    ]
  ]
  if Flood_type = "Multiple"[
  let iter 0
  loop [
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
to Update_coefficient_TOTAL
  ;; coefficient of expected future loss
  let iter 0
  if Hyperbolic? [
  if Flood_type = "10_year"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST )))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "100_year"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_100Y_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_100Y_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME  + 1) PROB_100Y_LIST ) ))
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "Multiple"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1) PROB_LIST ) ))
      set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis + Hyperbolic_rate * (iter - TIME)) ^ (iter - TIME)) * ( item ( iter + TIME  + 1 ) PROB_10Y_LIST ) ))
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  ]
  if Flood_type = "10_year"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis  ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST )))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_10Y_LIST )))
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "100_year"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_100Y_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis  ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_100Y_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME  + 1) PROB_100Y_LIST ) ))
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
  if Flood_type = "Multiple"[
    loop [
      if iter >= (Period - TIME) [ stop ] ;; stop condition is range out of period
                                          ;; set different cumulative future loss
      set TOTAL replace-item 0 TOTAL ( ( item 0 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_LIST ) ))
      set TOTAL replace-item 1 TOTAL ( ( item 1 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_LIST ) ))
      set TOTAL replace-item 2 TOTAL ( ( item 2 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter ) * ( item ( iter + TIME + 1) PROB_LIST ) ))
      set TOTAL replace-item 3 TOTAL ( ( item 3 TOTAL) + ( 1 / (( 1 + Normal_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 4 TOTAL ( ( item 4 TOTAL) + ( 1 / (( 1 + Poor_dis ) ^ iter ) * ( item ( iter + TIME + 1 ) PROB_10Y_LIST ) ))
      set TOTAL replace-item 5 TOTAL ( ( item 5 TOTAL) + ( 1 / (( 1 + Government_dis ) ^ iter) ) * ( item ( iter + TIME  + 1 ) PROB_10Y_LIST ) )
      set iter iter + 1
      ;;show TOTAL  ;; show to check calculation
    ]
  ]
end
to Update_coefficient_SUBSIDY_PV    ;; function to update one-time subsidy
  set SUBSIDY_PV replace-item 0 SUBSIDY_PV ( Subsidy / ( 1 + Normal_dis ) ^ TIME )
  set SUBSIDY_PV replace-item 1 SUBSIDY_PV ( Subsidy / ( 1 + Poor_dis ) ^ TIME )
  set SUBSIDY_PV replace-item 2 SUBSIDY_PV ( Subsidy / ( 1 + Government_dis) ^ TIME )

end

to Update_values ;; Function to update values for agent
  if breed = normals
  [
    if Flood_type = "10_year"[
    set Future_loss (item 0 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y)
    ]
    if Flood_type = "100_year"[
    set Future_loss (item 0 TOTAL) * (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y)
    ]
    if Flood_type = "Multiple"[
    set Future_loss (((item 3 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y) + ((item 0 TOTAL) *  (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y))))
  ]
  ]
  if breed = poors
  [
    if Flood_type = "10_year"[
    set Future_loss (item 1 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2)
    ]
    if Flood_type = "100_year"[
    set Future_loss (item 1 TOTAL) * (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2)
    ]
    if Flood_type = "Multiple"[
    set Future_loss (((item 4 TOTAL) * (Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2) + ((item 1 TOTAL) *  (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2 ))))
    ]
  ]
end

to Ori_change_color
  if breed = normals[
    if Government_strategy = "One-time-Subsidy" [
      if Total_market_value  *  Moving_Cost_Multiplier <= Future_loss [
        if Ori_moved? = False [
          set Ori_moved? True
          set Ori_year TIME
        ]
       ]
    ]
  ]

  if breed = poors[
    if Total_market_value  *  Moving_Cost_Multiplier  <= Future_loss [
       if Ori_moved? = False [
          set Ori_moved? True
          set Ori_year TIME
        ]
      ]
    ]
end
to Change_color
  ;; if moving cost plus pv of subsidy is greater than future loss then residents will move
  if breed = normals[
    if Government_strategy = "One-time-Subsidy" [
      if Total_market_value * Moving_Cost_Multiplier - Subsidy - Future_loss <= threshold  [
        if Moved? = False [
        if Total_market_value * Moving_Cost_Multiplier - Future_loss < S_prime [

            set S_prime Total_market_value * Moving_Cost_Multiplier - Future_loss

          ]

        ;;; set new_move_year ticks
        set color color + 4  ;; change color to red if moved
        set Moved? True ;; resident has moved
        set Mot_year TIME
        if Flood_type = "Multiple"[
        set OBJECTIVE OBJECTIVE + (item 2 PAST_LOSS )*((Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y) + (item 5 PAST_LOSS )* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y))
        ;set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
        if Flood_type = "100_year" [
        set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y)
        ;set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
        if Flood_type = "10_year" [
        set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y)
        ;set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
      ]
    ]
  ]
  ]
  if breed = poors[
    if Government_strategy = "One-time-Subsidy" [
      if Total_market_value * Moving_Cost_Multiplier - Subsidy - Future_loss <= threshold [
        if moved? = False [

         if Total_market_value * Moving_Cost_Multiplier - Future_loss < S_prime [

            set S_prime Total_market_value * Moving_Cost_Multiplier - Future_loss

          ]




        set color color + 4  ;; change color to red if moved
        set moved? True ;; resident has moved
        set Mot_year TIME
        if Flood_type = "Multiple"[
        set OBJECTIVE OBJECTIVE +  ((item 2 PAST_LOSS )*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2) + (item 5 PAST_LOSS )* (Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2))
        set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
        if Flood_type = "100_year" [
        set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_100Y + Sq.ft. / 2500 * Cost_to_personal_property_100Y / 2)
        set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
        if Flood_type = "10_year" [
        set OBJECTIVE OBJECTIVE +  (item 2 PAST_LOSS )*(Structure_Value * Damage_pct_10Y + Sq.ft. / 2500 * Cost_to_personal_property_10Y / 2)
        set OBJECTIVE OBJECTIVE +  (item 2 SUBSIDY_PV )
          ]
       ]
      ]
    ]

  ]
end
to Input_10Y_flood_data ;; function to plug in flood probability data
  ;; initilize PROB_LIST and read probability data from outside source
  set PROB_10Y_LIST [ 0 ]
  file-close
  file-open "data/10_NY_4.5.csv"
  ;let iter 0
  loop [
    ifelse file-at-end? [
      stop ]
    [
      set PROB_10Y_LIST lput file-read PROB_10Y_LIST
      ;set iter iter + 1
    ]
  ]
  file-close
end
to Input_100Y_flood_data
  set PROB_100Y_LIST [ 0 ]
  file-close
  file-open "data/100_NY_4.5.csv"
  ;let iter 0
  loop [
    ifelse file-at-end? [
      stop ]
    [
      set PROB_100Y_LIST lput file-read PROB_100Y_LIST
      ;set iter iter + 1
    ]
  ]
  file-close
end
to Input_Mulitple
  set PROB_LIST [ 0 ]
  let iter 0
  let len length PROB_10Y_LIST
  loop [
    ifelse iter >= len [
      stop ]
    [
      set PROB_LIST lput (( item iter PROB_10Y_LIST) - (item iter PROB_100Y_LIST)) PROB_LIST
      set iter iter + 1
    ]
  ]
end
to Hide_moved
  ;set MOTIVATED count (turtles with [Mot_year != Ori_year])
  set hidden? True
  if Mot_year != Ori_year[
    set hidden? False
    set size 15
  ]
end
to write_data
export-world "world2.csv"
end
to Initialize_list ;; function to initialize lists
  set SUBSIDY_PV [] ;; initialize SUBSIDY_PV list help calculate gov's objective function
  set TOTAL [] ;; initialize TOTAL list residents future loss
  set PAST_LOSS [] ;; initialize PAST list help calculate gov's objective function
  set SUBSIDY_HYPERBOLIC []
  let iter 0
  set CLASS 6
  loop [
    if iter > CLASS [ stop ]
    set SUBSIDY_PV lput 0 SUBSIDY_PV
    set TOTAL lput 0 TOTAL
    set PAST_LOSS lput 0 PAST_LOSS
    ;set SUBSIDY_HYPERBOLIC lput 0 SUBSIDY_HYPERBOLIC
    set iter iter + 1
  ]
end
to Inundation_property_damage_cost
  set Cost_to_personal_property_10Y 0
  if Inundation_10Y > 0 and Inundation_10Y <= 2
  [ set Cost_to_personal_property_10Y 3172]
  if Inundation_10Y > 2 and Inundation_10Y <= 3
  [ set Cost_to_personal_property_10Y 4917]
  if Inundation_10Y > 3 and Inundation_10Y <= 4
  [ set Cost_to_personal_property_10Y 7207]
  if Inundation_10Y > 4 and Inundation_10Y <= 5
  [ set Cost_to_personal_property_10Y 13914]
  if Inundation_10Y > 5 and Inundation_10Y <= 6
  [ set Cost_to_personal_property_10Y 14777]
  if Inundation_10Y > 6 and Inundation_10Y <= 7
  [ set Cost_to_personal_property_10Y 17700]
  if Inundation_10Y > 7 and Inundation_10Y <= 8
  [ set Cost_to_personal_property_10Y 20624]
  if Inundation_10Y > 8 and Inundation_10Y <= 9
  [ set Cost_to_personal_property_10Y 23547]
  if Inundation_10Y > 9 and Inundation_10Y <= 10
  [ set Cost_to_personal_property_10Y 26470]
  if Inundation_10Y > 10 and Inundation_10Y <= 11
  [ set Cost_to_personal_property_10Y 29394]
  if Inundation_10Y > 11 and Inundation_10Y <= 12
  [ set Cost_to_personal_property_10Y 32317]
  if Inundation_10Y > 12 and Inundation_10Y <= 24
  [ set Cost_to_personal_property_10Y 43001]
  if Inundation_10Y > 24 and Inundation_10Y <= 36
  [ set Cost_to_personal_property_10Y 46633]
  if Inundation_10Y > 36
  [ set Cost_to_personal_property_10Y 50000]
  set Cost_to_personal_property_100Y 0
  if Inundation_100Y > 0 and Inundation_100Y <= 2
  [ set Cost_to_personal_property_100Y 3172]
  if Inundation_100Y > 2 and Inundation_100Y <= 3
  [ set Cost_to_personal_property_100Y 4917]
  if Inundation_100Y > 3 and Inundation_100Y <= 4
  [ set Cost_to_personal_property_100Y 7207]
  if Inundation_100Y > 4 and Inundation_100Y <= 5
  [ set Cost_to_personal_property_100Y 13914]
  if Inundation_100Y > 5 and Inundation_100Y <= 6
  [ set Cost_to_personal_property_100Y 14777]
  if Inundation_100Y > 6 and Inundation_100Y <= 7
  [ set Cost_to_personal_property_100Y 17700]
  if Inundation_100Y > 7 and Inundation_100Y <= 8
  [ set Cost_to_personal_property_100Y 20624]
  if Inundation_100Y > 8 and Inundation_10Y <= 9
  [ set Cost_to_personal_property_100Y 23547]
  if Inundation_100Y > 9 and Inundation_10Y <= 10
  [ set Cost_to_personal_property_100Y 26470]
  if Inundation_100Y > 10 and Inundation_100Y <= 11
  [ set Cost_to_personal_property_100Y 29394]
  if Inundation_100Y > 11 and Inundation_100Y <= 12
  [ set Cost_to_personal_property_100Y 32317]
  if Inundation_100Y > 12 and Inundation_100Y <= 24
  [ set Cost_to_personal_property_100Y 43001]
  if Inundation_100Y > 24 and Inundation_100Y <= 36
  [ set Cost_to_personal_property_100Y 46633]
  if Inundation_100Y > 36
  [ set Cost_to_personal_property_100Y 50000]
end
to Damage_structure_pct_conditions
  if Stories = 1 and Basement = ""
  [ Damage_percentage_onestory_nobasement ]
  if Stories != 1 and Basement = ""
  [ Damage_percentage_morethanonestory_nobasement ]
  if Stories = 1 and Basement != ""
  [ Damage_percentage_onestory_basement ]
  if Stories != 1 and Basement != ""
  [ Damage_percentage_morethanonestory_basement ]

end
to Damage_percentage_onestory_basement
  set Damage_pct_10Y 0
  if Inundation_10Y > 0 and Inundation_10Y <= 1
  [set Damage_pct_10Y 0.32]
  if Inundation_10Y > 1 and Inundation_10Y <= 2
  [set Damage_pct_10Y 0.387]
  if Inundation_10Y > 2 and Inundation_10Y <= 3
  [set Damage_pct_10Y 0.455]
  if Inundation_10Y > 3 and Inundation_10Y <= 4
  [set Damage_pct_10Y 0.522]
  if Inundation_10Y > 4 and Inundation_10Y <= 5
  [set Damage_pct_10Y 0.586]
  if Inundation_10Y > 5 and Inundation_10Y <= 6
  [set Damage_pct_10Y 0.645]
  if Inundation_10Y > 6 and Inundation_10Y <= 7
  [set Damage_pct_10Y 0.698]
  if Inundation_10Y > 7 and Inundation_10Y <= 8
  [set Damage_pct_10Y 0.742]
  if Inundation_10Y > 8 and Inundation_10Y <= 9
  [set Damage_pct_10Y 0.777]
  if Inundation_10Y > 9 and Inundation_10Y <= 10
  [set Damage_pct_10Y 0.801]
  if Inundation_10Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_10Y 0.811]

  set Damage_pct_100Y 0
  if Inundation_100Y > 0 and Inundation_100Y <= 1
  [set Damage_pct_100Y 0.32]
  if Inundation_100Y > 1 and Inundation_100Y <= 2
  [set Damage_pct_100Y 0.387]
  if Inundation_100Y > 2 and Inundation_100Y <= 3
  [set Damage_pct_100Y 0.455]
  if Inundation_100Y > 3 and Inundation_100Y <= 4
  [set Damage_pct_100Y 0.522]
  if Inundation_100Y > 4 and Inundation_100Y <= 5
  [set Damage_pct_100Y 0.586]
  if Inundation_100Y > 5 and Inundation_100Y <= 6
  [set Damage_pct_100Y 0.645]
  if Inundation_100Y > 6 and Inundation_100Y <= 7
  [set Damage_pct_100Y 0.698]
  if Inundation_100Y > 7 and Inundation_100Y <= 8
  [set Damage_pct_100Y 0.742]
  if Inundation_100Y > 8 and Inundation_100Y <= 9
  [set Damage_pct_100Y 0.777]
  if Inundation_100Y > 9 and Inundation_100Y <= 10
  [set Damage_pct_100Y 0.801]
  if Inundation_100Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_100Y 0.811]
end
to Damage_percentage_morethanonestory_basement
  set Damage_pct_10Y 0
  if Inundation_10Y > 0 and Inundation_10Y <= 1
  [set Damage_pct_10Y 0.223]
  if Inundation_10Y > 1 and Inundation_10Y <= 2
  [set Damage_pct_10Y 0.270]
  if Inundation_10Y > 2 and Inundation_10Y <= 3
  [set Damage_pct_10Y 0.319]
  if Inundation_10Y > 3 and Inundation_10Y <= 4
  [set Damage_pct_10Y 0.369]
  if Inundation_10Y > 4 and Inundation_10Y <= 5
  [set Damage_pct_10Y 0.419]
  if Inundation_10Y > 5 and Inundation_10Y <= 6
  [set Damage_pct_10Y 0.469]
  if Inundation_10Y > 6 and Inundation_10Y <= 7
  [set Damage_pct_10Y 0.518]
  if Inundation_10Y > 7 and Inundation_10Y <= 8
  [set Damage_pct_10Y 0.564]
  if Inundation_10Y > 8 and Inundation_10Y <= 9
  [set Damage_pct_10Y 0.608]
  if Inundation_10Y > 9 and Inundation_10Y <= 10
  [set Damage_pct_10Y 0.648]
  if Inundation_10Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_10Y 0.684]

  set Damage_pct_100Y 0
  if Inundation_100Y > 0 and Inundation_100Y <= 1
  [set Damage_pct_100Y 0.223]
  if Inundation_100Y > 1 and Inundation_100Y <= 2
  [set Damage_pct_100Y 0.270]
  if Inundation_100Y > 2 and Inundation_100Y <= 3
  [set Damage_pct_100Y 0.319]
  if Inundation_100Y > 3 and Inundation_100Y <= 4
  [set Damage_pct_100Y 0.369]
  if Inundation_100Y > 4 and Inundation_100Y <= 5
  [set Damage_pct_100Y 0.419]
  if Inundation_100Y > 5 and Inundation_100Y <= 6
  [set Damage_pct_100Y 0.469]
  if Inundation_100Y > 6 and Inundation_100Y <= 7
  [set Damage_pct_100Y 0.518]
  if Inundation_100Y > 7 and Inundation_100Y <= 8
  [set Damage_pct_100Y 0.564]
  if Inundation_100Y > 8 and Inundation_100Y <= 9
  [set Damage_pct_100Y 0.608]
  if Inundation_100Y > 9 and Inundation_100Y <= 10
  [set Damage_pct_100Y 0.648]
  if Inundation_100Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_100Y 0.684]
end
to Damage_percentage_onestory_nobasement
  set Damage_pct_10Y 0
  if Inundation_10Y > 0 and Inundation_10Y <= 1
  [set Damage_pct_10Y 0.233]
  if Inundation_10Y > 1 and Inundation_10Y <= 2
  [set Damage_pct_10Y 0.321]
  if Inundation_10Y > 2 and Inundation_10Y <= 3
  [set Damage_pct_10Y 0.401]
  if Inundation_10Y > 3 and Inundation_10Y <= 4
  [set Damage_pct_10Y 0.471]
  if Inundation_10Y > 4 and Inundation_10Y <= 5
  [set Damage_pct_10Y 0.532]
  if Inundation_10Y > 5 and Inundation_10Y <= 6
  [set Damage_pct_10Y 0.586]
  if Inundation_10Y > 6 and Inundation_10Y <= 7
  [set Damage_pct_10Y 0.632]
  if Inundation_10Y > 7 and Inundation_10Y <= 8
  [set Damage_pct_10Y 0.672]
  if Inundation_10Y > 8 and Inundation_10Y <= 9
  [set Damage_pct_10Y 0.705]
  if Inundation_10Y > 9 and Inundation_10Y <= 10
  [set Damage_pct_10Y 0.732]
  if Inundation_10Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_10Y 0.754]

  set Damage_pct_100Y 0
  if Inundation_100Y > 0 and Inundation_100Y <= 1
  [set Damage_pct_100Y 0.233]
  if Inundation_100Y > 1 and Inundation_100Y <= 2
  [set Damage_pct_100Y 0.321]
  if Inundation_100Y > 2 and Inundation_100Y <= 3
  [set Damage_pct_100Y 0.401]
  if Inundation_100Y > 3 and Inundation_100Y <= 4
  [set Damage_pct_100Y 0.471]
  if Inundation_100Y > 4 and Inundation_100Y <= 5
  [set Damage_pct_100Y 0.532]
  if Inundation_100Y > 5 and Inundation_100Y <= 6
  [set Damage_pct_100Y 0.586]
  if Inundation_100Y > 6 and Inundation_100Y <= 7
  [set Damage_pct_100Y 0.632]
  if Inundation_100Y > 7 and Inundation_100Y <= 8
  [set Damage_pct_100Y 0.672]
  if Inundation_100Y > 8 and Inundation_100Y <= 9
  [set Damage_pct_100Y 0.705]
  if Inundation_100Y > 9 and Inundation_100Y <= 10
  [set Damage_pct_100Y 0.732]
  if Inundation_100Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_100Y 0.754]
end
to Damage_percentage_morethanonestory_nobasement
  set Damage_pct_10Y 0
  if Inundation_10Y > 0 and Inundation_10Y <= 1
  [set Damage_pct_10Y 0.152]
  if Inundation_10Y > 1 and Inundation_10Y <= 2
  [set Damage_pct_10Y 0.209]
  if Inundation_10Y > 2 and Inundation_10Y <= 3
  [set Damage_pct_10Y 0.263]
  if Inundation_10Y > 3 and Inundation_10Y <= 4
  [set Damage_pct_10Y 0.314]
  if Inundation_10Y > 4 and Inundation_10Y <= 5
  [set Damage_pct_10Y 0.362]
  if Inundation_10Y > 5 and Inundation_10Y <= 6
  [set Damage_pct_10Y 0.407]
  if Inundation_10Y > 6 and Inundation_10Y <= 7
  [set Damage_pct_10Y 0.449]
  if Inundation_10Y > 7 and Inundation_10Y <= 8
  [set Damage_pct_10Y 0.488]
  if Inundation_10Y > 8 and Inundation_10Y <= 9
  [set Damage_pct_10Y 0.524]
  if Inundation_10Y > 9 and Inundation_10Y <= 10
  [set Damage_pct_10Y 0.557]
  if Inundation_10Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_10Y 0.587]

  set Damage_pct_100Y 0
  if Inundation_100Y > 0 and Inundation_100Y <= 1
  [set Damage_pct_100Y 0.152]
  if Inundation_100Y > 1 and Inundation_100Y <= 2
  [set Damage_pct_100Y 0.209]
  if Inundation_100Y > 2 and Inundation_100Y <= 3
  [set Damage_pct_100Y 0.263]
  if Inundation_100Y > 3 and Inundation_100Y <= 4
  [set Damage_pct_100Y 0.314]
  if Inundation_100Y > 4 and Inundation_100Y <= 5
  [set Damage_pct_100Y 0.362]
  if Inundation_100Y > 5 and Inundation_100Y <= 6
  [set Damage_pct_100Y 0.407]
  if Inundation_100Y > 6 and Inundation_100Y <= 7
  [set Damage_pct_100Y 0.449]
  if Inundation_100Y > 7 and Inundation_100Y <= 8
  [set Damage_pct_100Y 0.488]
  if Inundation_100Y > 8 and Inundation_100Y <= 9
  [set Damage_pct_100Y 0.524]
  if Inundation_100Y > 9 and Inundation_100Y <= 10
  [set Damage_pct_100Y 0.557]
  if Inundation_100Y > 10                     ;Inundation > 10 consider the same high damage to the house
  [set Damage_pct_100Y 0.587]
end
@#$#@#$#@
GRAPHICS-WINDOW
689
10
1690
1020
-1
-1
0.025
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
333
173
399
206
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

INPUTBOX
5
82
163
142
Flood_Height_Meters_10Y
1.11
1
0
Number

INPUTBOX
4
150
125
210
MHHW_Meters
2.543
1
0
Number

INPUTBOX
4
219
126
279
MSL_Meters
1.785
1
0
Number

CHOOSER
372
10
517
55
Location
Location
"NY"
0

CHOOSER
170
60
333
105
Government_Strategy
Government_Strategy
"One-time-Subsidy" "Fixed-Benefits"
0

SLIDER
138
194
310
227
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
139
238
311
271
Fix_benefit
Fix_benefit
0
10000
0.0
1
1
NIL
HORIZONTAL

SLIDER
140
280
312
313
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
185
330
357
363
Poor_dis
Poor_dis
0
1
0.18
0.01
1
NIL
HORIZONTAL

SWITCH
4
285
133
318
Hyperbolic?
Hyperbolic?
0
1
-1000

SLIDER
2
330
174
363
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
4
375
176
408
Subsidy
Subsidy
0
1000000
10000.0
100
1
NIL
HORIZONTAL

SLIDER
4
422
176
455
Threshold
Threshold
0
10000
0.0
1
1
NIL
HORIZONTAL

BUTTON
333
215
401
248
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
528
11
666
56
Flood_type
Flood_type
"100_year" "10_year" "Multiple"
2

PLOT
8
471
202
621
Number of moved
Time
Number
0.0
100.0
0.0
100.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [ moved?]"

BUTTON
170
14
234
47
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

INPUTBOX
377
69
516
129
House_Price_Cutoff
389000.0
1
0
Number

INPUTBOX
528
69
667
129
Moving_Cost_Multiplier
2.7
1
0
Number

PLOT
225
472
425
622
 Normal move pct
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
"default" 1.0 0 -16777216 true "" "plot count normals with[moved?] / count normals"

PLOT
446
476
651
626
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

BUTTON
332
263
440
296
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

PLOT
453
276
648
461
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

SLIDER
451
223
623
256
Government_dis
Government_dis
0
1
0.036
0.001
1
NIL
HORIZONTAL

INPUTBOX
6
10
162
70
Flood_Height_Meters_100Y
1.84
1
0
Number

BUTTON
254
16
346
49
NIL
write_data\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
689
437
975
625
Moved by influence
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

## EXPLAINING THE MODEL

This section will explain the details and logics of each function.

Setup
	This function loads the data by calling other functions into the interface, sets the global variables from the inputs, and presents the house at a location based on the GIS map.

Go
	For each TIME (year), each household will be updated with its' past loss, future loss, and subsidy in terms of present value until the household decides to move or it reaches year 100th.

House property
	This function called by Setup. It will set data to each turtle. Meters of innundation will be calulated from input data, then will be converted to inches. 

Setting agents
	Dividing turtles into low-income and normal-income breed. Initializing the turtles to be not moved. Also assigning damage percentage by calling other functions.

Update coefficient past
	To calculate past loss using a loop logic (for govenment's objective function). For each TIME period, the loop will end when calculating the past loss up to one year before. For example, we are at year 5, the past will be calculate from year 0 to 4.   

Update_coefficient_TOTAL
	To calculate future loss using a loop logic (for household's decision). For each TIME period, the loop will end when calculating the future loss from the next year until the end of the period(100). For example, we are at year 5, the future will be calculate from year 6 to 100.

Update_coefficient_SUBSIDY_PV 
	This function calculate present value of subsidy for low-income, normal-income,and government in every year, then place the values in a list. 

Update_values
	This function updates future loss for the turtles who do not move. For low-income, the cost to personal property is set to be half of the normal-income for the purposeod this study.

Change_color
*This model only built with One-time-Subsidy as a government strategy.
	This function will distinguish which house decides to move by changing to a lighter color. Further, it shows the moved year of each turtle, and the objective value for the govenrment.  

Input_10Y_flood_data and Input_100Y_flood_data
	These two functions are similar. They loads the flood probability and puts in a list 

Input_Multiple
	The flood probability is calculated by taking out 10-year from 100-year flood probability before creating a list. This step will avoid double counting two flood probability.

Hide_moved
	Hide Moved will make any turtle whose motivated moving year the same as its' orginal moving year. ??????

Initialize_list
	This function initializes lists including present value of Subsidy, future loss, and past loss.

Inundation_property_damage_cost
 	This if-function assign cost to personal property to each turtle based on its' inundation level and type of flood.

Damage_structure_pct_conditions
	A connecting function that type of houses to the corresponding damage percentage.

Damage_percentage
	Assigning damage percentage to the turtles based on the previous called "Damage_structure_pct_conditions" function.
 
  

## NETLOGO FEATURES

NETLOGO has an interesting feature named "Behavior Space". Access via Tools, then click BehaviorSpace. This allows user to run sensitivty analysis and exports as a data file. For example, user can set the BehaviorSpace to run a range of subsidy and obtain the result of government's objective function for further analysis. 

## RELATED MODELS

This model mimics the NetLogo Models Library named "GIS General Examples" to loads the world maps into the interface. This function helps represent close to the real location using the latitude and longitude to the world map.

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
  <experiment name="best_Subsidy" repetitions="1" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>OBJECTIVE</metric>
    <steppedValueSet variable="Subsidy" first="0" step="10000" last="1000000"/>
    <steppedValueSet variable="Moving_Cost_Multiplier" first="1" step="0.1" last="3"/>
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
