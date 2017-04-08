# FocusTracker

### Summary

FocusTracker is designed to track the attentiveness of drivers as they drive. It
does so by estimating the heart rate and other vital signs of drivers through a
live video clip from a smartphone camera that can be mounted in a car. The app
will alert the driver to take a rest if it determines his or her focus is lower
than a certain threshold. Our project may also be applied in other scenarios,
for example tracking the efficiency of office workers or students throughout a
day, to help them optimize their time usage.

### Background

Past [researches](http://p.chambino.com/dissertation/pulse.pdf)
have shown that color variations in video clips of a
person across video frames, due to breath or heart pulse, can be magnified such
that the heart rate of that person can be calculated solely based on the
image frames. However this algorithm requries that the person should remain
relatively static throughout the video capture. Drivers in real world however
will likely make body movements as they drive. Thus we attempt to combine this
algorithm with facial recognition and tracking in order to correct for the
driver's movement. We will potentially experiment with Lucas-Kanade or FFT
algorithm for this purpose. Since the algorithms may be computationally
expensive for a smartphone, we will also experiment with the tradeoff between
the algorithm runtime and accuracy. As a stretch goal, we may also build and
train CNN and / or RNN models that measures the driver's focus by taking in
images or a short duration of video as input.

### Challenge

While algorithms exist for heart pulse estimation through video, the algorithm
can be sensitive to noise and requires that the captured target to remain mostly
static. As a result the algorithm may not apply for our purpose. We may need to
preprocess the video clip by cropping the video to only contain a small window
containing the person's face. Also, computational runtime may be a concern. We
need to make sure our entire pipeline runs fast enough on a smartphone device.
For our stretch goal, it may take a considerable amount of time to train a
working CNN model.

### Goals & Deliverables
- **Final Goal**: In the end, we aim to deliver an iOS app that is able to evaluate how focused the user is, from video input signal, and alert the user to take a break if the algorithm thinks the user is not focused enough. The algorithm in the basic goal involves using the _Eulerian Video Magnification_ algorithm to detect the pulse, and use the pulse signal as the input to build a detector that detects focusness.
- **Stretch Goal**: Besides pulse signal, we want to use the [Google Mobile Vision API](https://developers.google.com/vision/face-detection-concepts) to detect more input signals about the face of the user, and build a machine learning model utilizing this input.
- **Evaluation Method**: First step, we want to measure that our pulse detector actually detects the pulse signal correctly. We will compare its result against a physical pulse detecting device such as iWatch and expect the difference to be small. Second, we want to make sure that our model's estimated focusness decrease as time goes on, and alerts the user after a reasonable amount of time (between 30 minutes and 2 hours). Third, for our stretch goal, we can measure the performance of the model using the [Kaggle StayAlert challenge](https://www.kaggle.com/c/stayalert#description).
- **Feasibility Evaluation**: We believe that it is a reasonable goal to implement an accurate and performant pulse tracker from vision signal in the time allotted. And we were lucky to have the Google Mobile Vision API which can be very useful for getting useful signals.

### Schedule
- **Before Checkpoint** Get familiar with the Algorithm by reading the paper. And plan different phases, abstractions before implement the algorithm. Set up an iOS app project to record video and do additional processing, and use Google Mobile Vision API to extract the bounding box of the face. After week1, we should have an app that filters out all the background signal and leaves just the face for us to work with. And we should be familiar with how the algorithm works.
- **Week 1, 2** Implement the pulse detection and be able to analyze the pulse signal from a 5-second video clip, test and debug to make sure that the pulse signal detected from video is solid and trustworthy to be used in future stages. (Two weeks)
- **Week 3** Implement basic app logic and UI. Take a 5-second clip every 5 minutes, and analyze the pulse signal from that. And implement a detector that takes as input all past pulse signals and outputs an estimated focusness number.
- **Week 4** Realize the stretch goal. Evaluate our final product. Do demos and presentations.

### Checkpoint (Updated on April 8, 2017)

Up to this date, we have completed the following:
- **Real-time Face Tracking** with Google Mobile Vision API
- **Armadillo-based FastICA Implementation**
[[https://github.com/pavelkang/FocusTracker/blob/master/ica_compare.png|alt=ica_result_comparison]]
- **Real-time Pulse Detection**

#### Progress Evaluation
#### What do we plan to show
#### preliminary results
