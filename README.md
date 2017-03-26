## Welcome to GitHub Pages

You can use the [editor on GitHub](https://github.com/pavelkang/FocusTracker/edit/master/README.md) to maintain and preview the content for your website in Markdown files.

Whenever you commit to this repository, GitHub Pages will run [Jekyll](https://jekyllrb.com/) to rebuild the pages in your site, from the content in your Markdown files.

### Markdown

Markdown is a lightweight and easy-to-use syntax for styling your writing. It includes conventions for

```markdown
Syntax highlighted code block

# Header 1
## Header 2
### Header 3

- Bulleted
- List

1. Numbered
2. List

**Bold** and _Italic_ and `Code` text

[Link](url) and ![Image](src)
```

For more details see [GitHub Flavored Markdown](https://guides.github.com/features/mastering-markdown/).

### Jekyll Themes

Your Pages site will use the layout and styles from the Jekyll theme you have selected in your [repository settings](https://github.com/pavelkang/FocusTracker/settings). The name of this theme is saved in the Jekyll `_config.yml` configuration file.

### Support or Contact

Having trouble with Pages? Check out our [documentation](https://help.github.com/categories/github-pages-basics/) or [contact support](https://github.com/contact) and we’ll help you sort it out.

### Goals & Deliverables
- **Final Goal**: In the end, we aim to deliver an iOS app that is able to evaluate how focused the user is, from video input signal, and alert the user to take a break if the algorithm thinks the user is not focused enough. The algorithm in the basic goal involves using the _Eulerian Video Magnification_ algorithm to detect the pulse, and use the pulse signal as the input to build a detector that detects focusness.
- **Stretch Goal**: Besides pulse signal, we want to use the [Google Mobile Vision API](https://developers.google.com/vision/face-detection-concepts) to detect more input signals about the face of the user, and build a machine learning model utilizing this input. 
- **Evaluation Method**: First step, we want to measure that our pulse detector actually detects the pulse signal correctly. We will compare its result against a physical pulse detecting device such as iWatch and expect the difference to be small. Second, we want to make sure that our model's estimated focusness decrease as time goes on, and alerts the user after a reasonable amount of time (between 30 minutes and 2 hours). Third, for our stretch goal, we can measure the performance of the model using the [Kaggle StayAlert challenge](https://www.kaggle.com/c/stayalert#description). 
- **Feasibility Evaluation**: We believe that it is a reasonable goal to implement an accurate and performant pulse tracker from vision signal in the time allotted. And we were lucky to have the Google Mobile Vision API which can be very useful for getting useful signals.
### Schedule
- **Week 1** Get familiar with the Algorithm by reading the paper. And plan different phases, abstractions before implement the algorithm. Set up an iOS app project to record video and do additional processing, and use Google Mobile Vision API to extract the bounding box of the face. After week1, we should have an app that filters out all the background signal and leaves just the face for us to work with. And we should be familiar with how the algorithm works.
- **Week 2** Implement the pulse detection and be able to analyze the pulse signal from a 5-second video clip, test and debug to make sure that the pulse signal detected from video is solid and trustworthy to be used in future stages.
- **Week 3** Implement basic app logic and UI. Take a 5-second clip every 5 minutes, and analyze the pulse signal from that. And implement a detector that takes as input all past pulse signals and outputs an estimated focusness number.
- **Week 4** Realize the stretch goal. (In case our week 2 goal takes longer than expected, we will spend two weeks on that and abandon the stretch goal.)
