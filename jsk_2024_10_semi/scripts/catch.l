(require "package://pr2eus/pr2-interface.l")
(require "package://pr2eus/pr2.l")
(load "package://pr2eus/pr2-interface.l")
(ros::roseus "pr2_send_joints")
(ros::load-ros-manifest "jsk_recognition_msgs")

;;pr2生成
(if (not (boundp '*pr2*)) (pr2-init))
(setq *ri* (instance pr2-interface :init))
(objects (list *pr2*))

;;コールバック関数
(setq *tfl* (instance ros::transform-listener :init))
(defun callback (msg)
  (ros::ros-info "detect circle ~A" msg)
  (print (send msg :point))
  (let ((circle-pose (instance geometry_msgs::posestamped :init)))
    (send circle-pose :pose :position (send msg :point))
    (send circle-pose :pose :orientation :x 0.0)
    (send circle-pose :pose :orientation :y 0.0)
    (send circle-pose :pose :orientation :z 0.0)
    (send circle-pose :pose :orientation :w 1.0)    
    (setq *target-coords* (send (ros::tf-pose->coords (send circle-pose :pose)) :copy-worldcoords))
    )
  (setq tfc (send *tfl* :lookup-transform "base_link" "head_mount_kinect_rgb_optical_frame" (ros::time 0)))
  (when tfc
    (setq *target-coords* (send tfc :transform  *target-coords*))
    (send *target-box* :move-to *target-coords* :world)
    (print "update target position")))

(defun init-pose ()
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
  (setq *target-box* (make-cube 100 100 100))
  (objects (list *pr2* *target-box*))


  ;;サブスクライブ
  (ros::subscribe "/pointcloud_screenpoint/output_point" geometry_msgs::PointStamped #'callback)

  ;;ボールが見つかるまでループ
  (ros::ros-info "wait for target ~A" (send *target-box* :worldpos))
  (ros::rate 3) ;; 3Hz
  (while (< (elt (send *target-box* :worldpos) 2) 100)
    (send *pr2* :angle-vector (send *ri* :state :potentio-vector))
    (send *irtviewer* :draw-objects)
    (x::window-main-one)
    (ros::spin-once)
    (ros::ros-info "waiting... ~A" (send *target-box* :worldpos))
    (ros::sleep)
    )
  (ros::ros-info "start grasping... ~A" (send *target-box* :worldpos))


  ;;自分の台座とぶつからないようにアームを動かす
  ;; :larm, :rarm, :arms
  (setq arm :larm)
  (send *pr2* arm :inverse-kinematics
	(send (send *target-box* :copy-worldcoords) :translate #f(-100 0 0)))

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 3000)
  (send *ri* :wait-interpolation)

  (send *pr2* arm :inverse-kinematics
	(send (send *target-box* :copy-worldcoords) :translate #f(-50 0 -20)))

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 3000)
  (send *ri* :wait-interpolation)

  ;;掴む
  (send *ri* :start-grasp arm :wait t)
  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 1000)
  (send *ri* :wait-interpolation)


  ;;足にぶつからないような軌道で中央へ
  (send *pr2* arm :inverse-kinematics
	  (send (send *target-box* :copy-worldcoords) :translate #f(0 0 100)))

  (send *irtviewer* :draw-objects)
  (send *ri* :angle-vector (send *pr2* :angle-vector) 3000)
  (send *ri* :wait-interpolation)
)



;;メイン処理の実行
(ros::ros-info "init-pose")
(init-pose)
(unix:sleep 3)
(ros::ros-info "pick up")
(pick-up)
(unix:sleep 3)
(init-pose)

