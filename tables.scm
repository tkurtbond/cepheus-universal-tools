(define d6 (make-d 6))

(defstruct section title tables)
(defstruct table title die-roll data)
(define alien-creation-i
  (make-section
   title: "Alien Creation I"
   tables:
   (list 
    (make-table
     title: "Chemical Basis"
     data: 
     '(((03 . 05) "Hydrogen-Based Life (Frozen worlds below -250° F or Gas Giants)")
       ((06 . 07) "Ammonia-Based Life (Frozen worlds between -100° F and -30° F)")
       ((08) "Hydrocarbon-Based Life (Cold to Cool worlds)")
       ((09 . 11) "Water-Based Life (Cold to Hot worlds)")
       ((12) "Chlorine-Based Life (Cold to Tropical worlds)")
       ((13) "Silicon/Sulfuric Acid Life (Warm to Infernal worlds between 50° F and 600° F)")
       ((14) "Silicon/Liquid Sulfur Life (Infernal worlds between 250° F and 750° F)")
       ((15) "Silicon/Liquid Rock Life (Infernal worlds above 2500° F, or mantle)")
       ((16) "Plasma Life (Infernal worlds or stars above 4000° F)")
       ((17 . 18) "Exotica (Nebula-dwelling life, Machine life, Magnetic life)"))))))
 
(define alien-creation-ii
  (make-section
   title: "Alien Creation II"
   talbes:
   (list
    (make-table
     title: "Land or Water"
     data: '(((1 . 3) "Land")
             ((4 . 5) "Water")))
    (make-table
     title: "Land Habitat"
     data:
     '(((3 . 7) "Plains")
       ((8) "Desert")
       ((9) "Island/Beach")
       ((10) "Woodlands")
       ((11) "Swampland")
       ((12) "Mountain")
       ((13) "Artic")
       ((14 . 18) "Jungle")))
    (make-table
     title: "Water Habitat"
     data:
     '(((3 . 7) "Banks")
       ((8) "Open Ocean")
       ((9) "Fresh-Water Lakes")
       ((10) "River/Stream")
       ((11) "Tropical Lagoon")
       ((12) "Deep-Ocean Vents")
       ((13) "Salt-Water Sea")
       ((14 . 18) "Reef"))
                
