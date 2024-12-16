(require "package://pr2eus/pr2-interface.l")
(require "package://pr2eus/pr2.l")
(load "package://pr2eus/pr2-interface.l")
(ros::roseus "pr2_send_joints")
(ros::load-ros-manifest "jsk_recognition_msgs")

;;pr2生成
(if (not (boundp '*pr2*)) (pr2-init))
(setq *ri* (instance pr2-interface :init))
(objects (list *pr2*))

(setq *tfl* (instance ros::transform-listener :init))
;;検知したboxとラベルを対応させるクラス
(defclass box-label-synchronizer
  :super exact-time-message-filter)

(defmethod box-label-synchronizer
  (:callback (box-msg label-msg)
    (print (list box-msg label-msg))
    (print (send-all (list box-msg label-msg) :header :stamp))
    (box-cb box-msg label-msg)
  )
)

;;コールバック関数
;;/docker/detic_segmentor/detected_classesというトピックにidの対応あり
(defun box-cb (box-msg label-msg)
  (ros::ros-info "received ~A boxes, ~A labels" (length (send box-msg :boxes)) (length (send label-msg :labels)))
  (dolist (msg-conbined (map cons #'(lambda (x y) (list  x y)) (send box-msg :boxes) (send label-msg :labels)))
    (let (box label)
      ;;(print (list msg-conbined))
      (setq box (car msg-conbined) label (cadr msg-conbined))
      ;;(print (list box label))
      (ros::ros-info "box ~A, label ~A" (send box :pose) (send label :name))
      (when (or (string= (send label :name) "ball") (string= (send label :name) "soccer_ball") (string= (send label :name) "beachball"));; 41 -> ball, 1110 ->toy 
        (setq *target-coords* (send (ros::tf-pose->coords (send box :pose)) :copy-worldcoords))
        ;; (setq tfc (send *tfl* :lookup-transform "base_link" "head_mount_kinect_rgb_optical_frame" (ros::time 0)))
        ;; (print *target-coords*)
        ;; (when *tfl*
        ;;  (setq *target-coords* (send tfc :transform  *target-coords*))
        ;; )
        ;; (print *target-coords*)
        (setq *target-dimensions* (send box :dimensions))
        (format t "coords ~A, dimension ~A~%" (send *target-coords* :worldcoords) (* (send *target-dimensions* :x) (send *target-dimensions* :y) (send *target-dimensions* :z)))
        ; (when (and (< (elt (send *target-coords* :worldpos) 2) 400)
        ;     (> (elt (send *target-coords* :worldpos) 2) -400))
        (send *target-box* :move-to *target-coords* :world)
        (ros::ros-info "update target position")
        ; )
      )
    )
  )
)

;;コールバック関数
; (setq *tfl* (instance ros::transform-listener :init))
; (defun callback (msg)
;   (ros::ros-info "detect circle ~A" (send msg :point))
;   (let ((circle-pose (instance geometry_msgs::posestamped :init)))
;     (send circle-pose :pose :position (send msg :point))
;     (send circle-pose :pose :orientation :x 0.0)
;     (send circle-pose :pose :orientation :y 0.0)
;     (send circle-pose :pose :orientation :z 0.0)
;     (send circle-pose :pose :orientation :w 1.0)    
;     (setq *target-coords* (send (ros::tf-pose->coords (send circle-pose :pose)) :copy-worldcoords))
;   )
;   (setq tfc (send *tfl* :lookup-transform "base_link" "head_mount_kinect_rgb_optical_frame" (ros::time 0)))
;   (when tfc
;     (setq *target-coords* (send tfc :transform  *target-coords*))
;     (send *target-box* :move-to *target-coords* :world)
;     (ros::ros-info "update target position")
;   )
; )

(defun init-pose ()
  (send *ri* :speak-jp "初期姿勢に移動します" :wait t)
  (send *pr2* :reset-pose)
  (send *ri* :stop-grasp :arms)
  (send *irtviewer* :draw-objects) 
  (send *ri* :angle-vector (send *pr2* :angle-vector) 3000)
  (send *ri* :wait-interpolation)
)

(defun pick-up ()
  (send *pr2* :head :neck-p :joint-angle 60)
  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
  (send *ri* :wait-interpolation)


  ;;boxを適当な初期位置で配置
  (setq *target-box* (make-cube 0 0 -10))
  (objects (list *pr2* *target-box*))


  ;;サブスクライブ
  ; (ros::subscribe "/pointcloud_screenpoint/output_point" geometry_msgs::PointStamped #'callback)
  (setq box-sync (instance box-label-synchronizer :init
			   (list (list "/docker/detic_segmentor/output/boxes" jsk_recognition_msgs::BoundingBoxArray)
				 (list "/docker/detic_segmentor/detected_classes" jsk_recognition_msgs::LabelArray))))

  ;;ボールが見つかるまでループ
  (send *ri* :speak-jp "ボールをさがしています" :wait t)
  (ros::rate 3) ;; 3Hz
  (while (< (elt (send *target-box* :worldpos) 2) 100)
    (ros::ros-info "waiting... ~A" (send *target-box* :worldpos))
    (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    (send *irtviewer* :draw-objects)
    (x::window-main-one)
    (ros::spin-once)
    (ros::sleep)
  )
  (send *ri* :speak-jp "ボールを見つけました" :wait t)
  (ros::ros-info "start grasping... ~A" (send *target-box* :worldpos))
  (send *pr2* :larm :shoulder-p :joint-angle 0)
  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
  (send *ri* :wait-interpolation)


  ;;自分の台座とぶつからないようにアームを動かす
  (setq arm :larm)
  (send *pr2* arm :inverse-kinematics
	  (send (send (send *target-box* :copy-worldcoords) :translate #f(0 0 100)) :rotate (deg2rad 90) :y)
    :rotation-axis t
  )

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 2000)
  (send *ri* :wait-interpolation)

  (send *pr2* arm :inverse-kinematics
	  (send (send (send *target-box* :copy-worldcoords) :translate #f(0 0 0)) :rotate (deg2rad 90) :y)
    :rotation-axis t
  )

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 2000)
  (send *ri* :wait-interpolation)

  ;;掴む
  (send *ri* :start-grasp arm :wait t)
  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
  (send *ri* :wait-interpolation)


  ;;足にぶつからないような軌道で中央へ
  (send *pr2* arm :inverse-kinematics
	  (send (send *target-box* :copy-worldcoords) :translate #f(-100 0 200)))

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 2000)
  (send *ri* :wait-interpolation)
)



;;メイン処理の実行
(ros::ros-info "init-pose")
(init-pose)
(unix:sleep 1)
(ros::ros-info "pick up")
(pick-up)
(unix:sleep 1)
(init-pose)

