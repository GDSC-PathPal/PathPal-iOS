
# Google Developer Student Clubs 2024 Solution Challenge
<br>

<img src="https://github.com/GDSC-PathPal/PathPal-iOS/assets/97840728/c0897eb3-76b4-4145-91e6-e64981cac42b" alt="표지" style="width:80%;" />
  
<br>
<br>

# ‣ Introduction
PathPal is a solution helps visually impaired people walk safely. 
PathPal provides an accurate route is provided through voice guidance from the starting point to the destination. In addition, it collects visual information through cameras, detects objects and analyzes them using AI/ML to informs users to prevent risk factors through voice and vibration.

<br>

### Watch the product demo on:

<a href="https://www.youtube.com/watch?v=7HeddwSCQK8"> 
    <img src="https://img.shields.io/badge/YouTube-%23FF0000.svg?style=for-the-badge&logo=YouTube&logoColor=white" alt="Youtube"/>
  </a> 	


<br>
<br>


# ‣ Initial sruvey and Probelm statement research

## complaints
<img src="https://github.com/GDSC-PathPal/PathPal-iOS/assets/97840728/b27cca0e-4dd1-4b9d-9bfb-c18c1550e2b9" alt="overview-h p" style="width:80%;" />

## needs of assistive device
<img src="https://github.com/GDSC-PathPal/PathPal-iOS/assets/97840728/058ff0c3-7a7f-4945-af70-c81cfd6412f4" alt="시장규모" style="width:80%;" />

<br>

- Of the 1.1 billion visually impared around the world, 44% have severe disabilities.
- Additionally, the global assistive device market size exceeded 14 billion$ in 2015. It is expected to reach approximately 25.6 billion$ in 2026.

<br>  
<br>
<br>


# ‣ Mockup

<img src="https://github.com/GDSC-PathPal/PathPal-iOS/assets/97840728/0c62f68c-5103-4307-9538-d6c7058bd95a" alt="솔루션" style="width:80%;" />

<br>

1. users can receive voice guidance for the route when they enter thier starting and arraival point.
2. If user is heading a correct starting direction, navigation will begin with vibration.
3. results of the camera screen analyzed by stride of the visually impaired person, will be announced through voice and vibration.
4. In the example screen, you can receive voice guidance such as, “crosswalk in the center and bollard on the right detected”

<br>

<br>
<br>


# ‣ Key Features

## Navigation
- Current location and heading Management
- Voice search for starting and destination
- Setting the correct starting direction using a compass

<br>

## Vision Assistance
- Voice guidance on objects and their locations shown on the camera screen
  - Detectable objects : beverage vending machine, bicycle road, braille sign, brailleblock, chair, resting place, lift , crosswalk, trashcan, green traffic
- Vibration guidance when detecting an accident-causing obstacle
  - Detectable Risks : block kind bad, raised curb, Pillar, bollard, barricade

<br>
 
## Globalization

<img width="692" src="https://github.com/GDSC-PathPal/.github/assets/97840728/0d2ceaed-698b-4d5e-8a95-b9c5ffc07803">


<br>
<br>
<br>

# ‣ Simulation

<br>
<br>

<br>

# ‣ UN SDGs to fulfil


<img src="https://github.com/GDSC-PathPal/PathPal-iOS/assets/97840728/7dcf1db8-e8b7-4331-b721-7306610d9791" alt="목표 SDGs" style="width:80%;" />


<br>
<br>
<br>

# ‣ Expected Values

<br>
<br>


# ‣ Technical Features
<br>

## Architecture
<br>

![Group 560849](https://github.com/GDSC-PathPal/.github/assets/97840728/cd719a2f-2dff-46be-a587-5046fb9759c8)

<br>
 
## iOS

<br>
 
## AI/ML

<br>


## Backend

<br>



# ‣ Getting Started
Download Femunity directly from our GitHub repository. After downloading the app, you can sign up for an account using your Google account or use Guest Mode to explore the app.

### Prerequisites
Before you start, make sure you have installed the following on your system:
- JDK 17

### Installation
ML & Server
- Clone the Pathpal repository from GitHub
   - ML : https://github.com/GDSC-PathPal/PathPal-ML
   - Server : https://github.com/GDSC-PathPal/PathPal-Server
- Start ML
  - pip install -r requirements.txt
  - python inference_yolov8.py
- Start Server
  - java -jar PathPal-0.1.0.jar
  - **You must turn on the server after the ML server is turned on**

# ‣ License
PathPal-Server is licensed under the terms of the MIT license. See [License.txt](https://github.com/GDSC-PathPal/.github/blob/main/LICENSE) for more information
