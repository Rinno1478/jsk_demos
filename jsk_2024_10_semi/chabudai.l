(require "package://pr2eus/pr2.l")  ;;import pr2 package
(require "package://pr2eus/pr2-utils.l")
(require "package://pr2eus/pr2-interface.l") 
(if (not (boundp '*pr2*)) (setq *pr2* (pr2)));; (setq *pr2* (pr2)))  ;; (pr2) is alternated by  *pr2*

; (send *pr2* :reset-pose) ;; 初期姿勢
; (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
; (send *ri* :wait-interpolation)
; (objects (list *pr2*))

;; 一辺600mmの立方体を出現させる
(setq *cube* (make-cube 600 600 600))
;; 立方体を(700, 0, 300)移動
(send *cube* :translate (float-vector 700 0 300))
(objects (list *pr2*))

;; PR2の腕を指定の角度に動かす
(send *pr2* :larm :shoulder-p :joint-angle 15)
(send *pr2* :larm :shoulder-r :joint-angle 90)
(send *pr2* :larm :collar-y :joint-angle 45)
(send *pr2* :larm :elbow-p :joint-angle -100)
(send *pr2* :larm :elbow-r :joint-angle 0)
(send *pr2* :larm :wrist-p :joint-angle -10)
(send *pr2* :larm :wrist-r :joint-angle 0)
(send *pr2* :rarm :shoulder-p :joint-angle 15)
(send *pr2* :rarm :shoulder-r :joint-angle -90)
(send *pr2* :rarm :collar-y :joint-angle -45)
(send *pr2* :rarm :elbow-p :joint-angle -100)
(send *pr2* :rarm :elbow-r :joint-angle 0)
(send *pr2* :rarm :wrist-p :joint-angle -10)
(send *pr2* :rarm :wrist-r :joint-angle 0)
(send *pr2* :head :neck-p :joint-angle 50)
(send *irtviewer* :draw-objects)

;; sleep 2秒
(unix:sleep 2)
(send *pr2* :larm :shoulder-p :joint-angle 0)
(send *pr2* :larm :shoulder-r :joint-angle 5)
(send *pr2* :rarm :shoulder-p :joint-angle 0)
(send *pr2* :rarm :shoulder-r :joint-angle -5)
(send *pr2* :head :neck-p :joint-angle -10)
(send *irtviewer* :draw-objects)
; (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
; (send *ri* :wait-interpolation)