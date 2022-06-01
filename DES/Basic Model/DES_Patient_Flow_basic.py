import simpy
import numpy as np
from numpy.random import RandomState, randint
import pandas as pd
import matplotlib.pyplot as plt

# Arrival rate and length of stay inputs.
ARR_RATE = 0.9
MEAN_LOS_TREATMENT = 3

CAPACITY_TREATMENT = 10
CAPACITY_DOCTOR = 2

Treatment_Waiting_Times = [ ]
Doctor_Waiting_Times = [ ]
Doctor_UnderUtilized = [ ]


RNG_SEED = 6353

def patient_generator(env, arr_rate, prng=RandomState(0)):
    """Generates patients according to a simple Poisson process

        Parameters
        ----------
        env : simpy.Environment
            the simulation environment
        arr_rate : float
            exponential arrival rate
        prng : RandomState object
            Seeded RandomState object
    """

    patients_created = 0

    # Infinite loop for generating patients according to a poisson process.
    while True:

        # Generate next interarrival time
        iat = prng.exponential(1.0 / arr_rate)

        # Generate length of stay in treatment unit with doctor for this patient
        los_treatment = prng.exponential(MEAN_LOS_TREATMENT)

        # Update counter of patients
        patients_created += 1

        # Create a new patient flow process.
        ED = ED_patient_flow(env, 'Patient{}'.format(patients_created),
                             los_treatment=los_treatment)

        # Register the process with the simulation environment
        env.process(ED)

        # This process will now yield to a 'timeout' event. This process will resume after iat time units.
        yield env.timeout(iat)


def ED_patient_flow(env, name, los_treatment):
    """Simulate Patient flow in ED
        Parameters
        ----------
        env : simpy.Environment
            the simulation environment
        name : str
            process instance id
        los_treatment : float
            length of stay in Treatment unit
    """

    print("{} trying to get Treatment at {}".format(name, env.now))

    # Timestamp when patient tried to get into treatment
    treatment_unit_request_ts = env.now
    # Request a treatment unit
    treatment_unit_request = treatment_unit.request()
    
    numberofUnderUtilized = CAPACITY_DOCTOR - doctor_unit.count
    Doctor_UnderUtilized.append(numberofUnderUtilized)
    print("At {} , number of under-utilized doctors is: {}".format(treatment_unit_request_ts, numberofUnderUtilized))
    # Yield this process until a treatment unit
    yield treatment_unit_request
    # We got a treatment unit

    print("{} entering Treatment at {}".format(name, env.now))
    # Let's see if we had to wait to get into treatment.
    if env.now > treatment_unit_request_ts:
        treatment_unit_waiting_time = env.now - treatment_unit_request_ts
        print("{} waited {} time units for entering Treatment room".format(name, treatment_unit_waiting_time))
        Treatment_Waiting_Times.append(treatment_unit_waiting_time)
    else:
        Treatment_Waiting_Times.append(0)


    # Timestamp when patient tried to get doctor
    doctor_unit_request_ts = env.now
    # Request a doctor 
    doctor_unit_request = doctor_unit.request()
    # Yield this process until a doctor is available
    yield doctor_unit_request
    # We got a doctor
    print("{} has doctor treating patient at {}".format(name, env.now))
    # Let's see if we had to wait to get the doctor.
    if env.now > doctor_unit_request_ts:
        doctor_unit_waiting_time = env.now - doctor_unit_request_ts
        print("{} waited {} time units for Doctor".format(name, doctor_unit_waiting_time))
        Doctor_Waiting_Times.append(doctor_unit_waiting_time)
    else:
        Doctor_Waiting_Times.append(0)


    # How long the patient stayed in treatment
    waited_in_treatment = env.now
    # Yield this process again. Now wait until our length of stay elapses.
    # This is the actual stay in the treatment
    yield env.timeout(los_treatment)

    # All done with treatment and doctor units, release the doctor and treatment unit to be available.
    treatment_unit.release(treatment_unit_request)
    print("{} leaving Treatment at {}".format(name, env.now))

    doctor_unit.release(doctor_unit_request)
    print("Doctor is now free at {}".format(env.now))
    
    # Waiting Time for treatment room
    print("{} has stayed {} time units at treatment room".format(name, env.now - waited_in_treatment))






# Initialize a simulation environment
env = simpy.Environment()
prng = RandomState(RNG_SEED)

# Declare treatment and doctor resources.
treatment_unit = simpy.Resource(env, CAPACITY_TREATMENT)
doctor_unit = simpy.Resource(env , CAPACITY_DOCTOR )

# Run the simulation for a while
runtime = 50
env.process(patient_generator(env, ARR_RATE, prng))
env.run(until=runtime)
plt.subplot(1,2,1)
plt.plot(Doctor_Waiting_Times,color='blue',label='Patient waiting for doctor')
plt.plot(Treatment_Waiting_Times,color='black',label = 'Patient Waiting for treatment')
plt.title("Waiting Times")
plt.ylabel('Waiting time')
plt.xlabel('Patient Number')
plt.legend()
plt.subplot(1,2,2)
plt.plot(Doctor_UnderUtilized,color='red',label = 'Under utilized doctors')
plt.title("Under utilized doctors")
plt.ylabel('Number of doctors')
plt.xlabel('Patient Number')
plt.legend()

plt.show()

