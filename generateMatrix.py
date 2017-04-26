import numpy as np
import matplotlib.pyplot as plt
from scipy import signal
import pickle
from sklearn.decomposition import FastICA, PCA

np.random.seed(0)

def to_itpp(mat, name):
    mat = mat.tolist()
    res = ""
    for row in mat:
        res += " ".join(map(lambda x: str(x), row))
        res += ";"
    with open(name, 'wb') as f:
        f.write(res)

def to_arma(mat, name):
    mat = mat.tolist()
    res = ""
    for row in mat:
        res += " ".join(map(lambda x: str(x), row))
        res += "\n"
    with open(name, 'wb') as f:
        f.write(res)

for n_samples in [100, 500, 1000, 2000, 3000, 5000]:

    time = np.linspace(0, 8, n_samples)

    s1 = np.sin(2 * time)  # Signal 1 : sinusoidal signal
    s2 = np.sign(np.sin(3 * time))  # Signal 2 : square signal
    s3 = signal.sawtooth(2 * np.pi * time)  # Signal 3: saw tooth signal

    S = np.c_[s1, s2, s3]
    S += 0.2 * np.random.normal(size=S.shape)  # Add noise

    S /= S.std(axis=0)  # Standardize data
    # Mix data
    A = np.array([[1, 1, 1], [0.5, 2, 1.0], [1.5, 1.0, 2.0]])  # Mixing matrix
    X = np.dot(S, A.T)  # Generate observations
    X = X.T
    print X.shape
    to_itpp(X, "/Users/kai/FocusTracker/itpp-"+str(n_samples)+'.mat')
    to_arma(X, "/Users/kai/FocusTracker/arma-"+str(n_samples)+'.mat')
