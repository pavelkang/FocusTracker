#include "ica.h"

using namespace std;
using namespace arma;

static void remmean(mat inVectors, mat & outVectors, vec & meanValue);
static int pcamat(const mat vectors, const int numOfIC, int firstEig,
                  int lastEig, mat & Es, vec & Ds);
static void selcol(const mat oldMatrix, const vec maskVector, mat &newMatrix);
static void whitenv(const mat vectors, const mat E, const mat D,
                    mat & newVectors, mat & whiteningMatrix,
                    mat & dewhiteningMatrix);
static bool fpica(const mat X, const mat whiteningMatrix,
                  const mat dewhiteningMatrix, const int approach,
                  const int numOfIC, const int g, const int finetune,
                  const double a1, const double a2, double myy,
                  const int stabilization, const double epsilon,
                  const int maxNumIterations, const int maxFinetune,
                  const int initState, mat guess,
                  double sampleSize, mat & A, mat & W);
static uvec getSamples(const int max, const double percentage);

vec elem_mult(vec a, vec b) {
  vec res;
  for (int i = 0; i < a.n_elem; i++) {
    res(i) = a(i) * b(i);
  }
  return res;
}

Fast_ICA::Fast_ICA(mat ma_mixed_sig) {
  approach = FICA_APPROACH_DEFL;
  g = FICA_NONLIN_TANH;
  finetune = true;
  a1 = 1.0;
  a2 = 1.0;
  mu = 1.0;
  epsilon = 0.0001;
  sampleSize = 1.0;
  stabilization = false;
  maxNumIterations = 10000;
  maxFineTune = 10;
  firstEig = 1;
  mixedSig = ma_mixed_sig;
  lastEig = mixedSig.n_rows;
  numOfIC = mixedSig.n_rows;
  PCAonly = false;
  initState = FICA_INIT_RAND;
}

static int pcamat(
  const mat vectors,
  const int numOfIC,
  int firstEig,
  int lastEig,
  mat &Es,
  vec &Ds
  ) {
  mat Et;
  vec Dt;
  mat Ec;
  vec Dc;
  double lowerLimitValue = 0.0,
    higherLimitValue = 0.0;
  int oldDimension = vectors.n_rows;
  mat covarianceMatrix = cov(trans(vectors));
  eig_sym(Dt, Et, covarianceMatrix);
  int maxLastEig = 0;
  for (int i = 0; i < Dt.n_elem; i++) {
    if (Dt(i) > FICA_TOL)
      maxLastEig++;
  }
  if (maxLastEig < 1)
    return 0;
  if (maxLastEig > numOfIC)
    maxLastEig = numOfIC;

  vec eigenvalues; eigenvalues.zeros(Dt.n_elem);
  vec eigenvalues2; eigenvalues2.zeros(Dt.n_elem);

  eigenvalues2 = Dt;
  eigenvalues2 = sort(eigenvalues2);
  vec lowerColumns; lowerColumns.zeros(Dt.n_elem);
  for (int i = 0; i < Dt.n_elem; i++) {
    eigenvalues(i) = eigenvalues2(Dt.n_elem - i - 1);
  }
  if (lastEig > maxLastEig)
    lastEig = maxLastEig;
  if (lastEig < oldDimension)
    lowerLimitValue = (eigenvalues(lastEig - 1) + eigenvalues(lastEig)) / 2;
  else
    lowerLimitValue = eigenvalues(oldDimension - 1) - 1;
  for (int i = 0; i < Dt.n_elem; i++) {
    if (Dt(i) > lowerLimitValue)
      lowerColumns(i) = 1;
  }
  if (firstEig > 1)
    higherLimitValue = (eigenvalues(firstEig - 2) + eigenvalues(firstEig - 1)) / 2;
  else
    higherLimitValue = eigenvalues(0) + 1;

  vec higherColumns; higherColumns.zeros(Dt.n_elem);
  for (int i = 0; i < Dt.n_elem; i++) {
    if (Dt(i) < higherLimitValue)
      higherColumns(i) = 1;
  }

  vec selectedColumns; selectedColumns.zeros(Dt.n_elem);
  for (int i = 0; i < Dt.n_elem; i++) {
    selectedColumns(i) = (lowerColumns(i) == 1 && higherColumns(i) == 1) ? 1 : 0;
  }

  selcol(Et, selectedColumns, Es);

  int numTaken = 0;
  for (int i = 0; i < selectedColumns.n_elem; i++) {
    if (selectedColumns(i) == 1)
      numTaken++;
  }
  Ds.zeros(numTaken);
  numTaken = 0;
  for (int i = 0; i < Dt.n_elem; i++) {
    if (selectedColumns(i) == 1) {
      Ds(numTaken) = Dt(i);
      numTaken++;
    }
  }
  return lastEig;
}

bool Fast_ICA::separate(void) {
  int Dim = numOfIC;
  mat mixedSigC;
  vec mixedMean;

  mat guess;
  if (initState == FICA_INIT_RAND)
    guess.zeros(Dim, Dim);
  else
    guess = mat(initGuess);

  VecPr.zeros(mixedSig.n_rows, numOfIC);
  icasig.zeros(numOfIC, mixedSig.n_cols);
  remmean(mixedSig, mixedSigC, mixedMean);

  if (pcamat(mixedSigC, numOfIC, firstEig, lastEig, E, D) < 1) {
    icasig = mixedSig;
    return false;
  }

  whitenv(mixedSigC, E, diagmat(D),
          whitesig, whiteningMatrix, dewhiteningMatrix);

  Dim = whitesig.n_rows;
  if (numOfIC > Dim)
    numOfIC = Dim;

  // ivec? cvec?
  vec NcFirst; NcFirst.zeros(numOfIC);
  vec NcVp = D;
  for (int i = 0; i < NcFirst.n_elem; i++) {
    NcFirst(i) = arma::index_max(NcVp);
    NcVp(NcFirst(i)) = 0.0;
    VecPr.col(i) = dewhiteningMatrix.col(i);
  }

  bool result = true;
  if (PCAonly == false) {
    result = fpica(whitesig, whiteningMatrix, dewhiteningMatrix,
                   approach, numOfIC, g, finetune, a1, a2, mu,
                   stabilization, epsilon, maxNumIterations,
                   maxFineTune, initState, guess, sampleSize, A, W);
    icasig = W * mixedSig;
  } else {
    icasig = VecPr;
  }
  return result;
}

static void remmean(mat inVectors, mat &outVectors, vec &meanValue) {
  outVectors.zeros(inVectors.n_rows, inVectors.n_cols);
  meanValue.zeros(inVectors.n_rows);

  for (int i = 0; i < inVectors.n_rows; i++) {
    meanValue(i) = mean(inVectors.row(i));
    for (int j = 0; j < inVectors.n_cols; j++) {
      outVectors(i, j) = inVectors(i, j) - meanValue(i);
    }
  }
}

static void selcol(const mat oldMatrix, const vec maskVector, mat &newMatrix) {
  int numTaken = 0;
  for (int i = 0; i < maskVector.n_elem; i++) {
    if (maskVector(i) == 1)
      numTaken++;
  }
  newMatrix.zeros(oldMatrix.n_rows, numTaken);
  numTaken = 0;
  for (int i = 0; i < maskVector.n_elem; i++) {
    if (maskVector(i) == 1) {
      newMatrix.col(numTaken) = oldMatrix.col(i);
      numTaken++;
    }
  }
}

static void whitenv(const mat vectors, const mat E, const mat D,
                    mat & newVectors, mat & whiteningMatrix,
                    mat & dewhiteningMatrix) {
  whiteningMatrix.zeros(E.n_cols, E.n_rows);
  dewhiteningMatrix.zeros(E.n_rows, E.n_cols);
  for (int i = 0; i < D.n_cols; i++) {
    whiteningMatrix.row(i) = conv_to< rowvec >::from(std::pow(std::sqrt(D(i,i)), -1)*E.col(i));
    dewhiteningMatrix.col(i) = std::sqrt(D(i,i)) * E.col(i);
  }
  newVectors = whiteningMatrix * vectors;
}

static bool fpica(const mat X, const mat whiteningMatrix,
                  const mat dewhiteningMatrix, const int approach,
                  const int numOfIC, const int g, const int finetune,
                  const double a1, const double a2, double myy,
                  const int stabilization, const double epsilon,
                  const int maxNumIterations, const int maxFinetune,
                  const int initState, mat guess,
                  double sampleSize, mat & A, mat & W) {
  int vectorSize = X.n_rows;
  int numSamples = X.n_cols;
  int gOrig = g;
  int gFine = finetune + 1;
  double myyOrig = myy;
  double myyK = 0.01;
  int failureLimit = 5;
  int usedNlinearity = 0;
  double stroke = 0.0;
  int notFine = 1;
  int loong = 0;
  int initialStateMode = initState;
  double minAbsCos = 0.0, minAbsCos2 = 0.0;

  if (sampleSize * numSamples < 1000) {
    sampleSize = (1000 / (double) numSamples < 1.0) ? 1000 / (double) numSamples : 1.0;
  }
  if (sampleSize != 1.0) gOrig += 2;
  if (myy != 1.0) gOrig += 1;

  int fineTuningEnabled = 1;

  if (!finetune) {
    if (myy != 1.0) gFine = gOrig;
    else gFine = gOrig + 1;
    fineTuningEnabled = 0;
  }

  int stabilizationEnabled = stabilization;
  if (!stabilization && myy != 1.0) stabilizationEnabled = true;

  usedNlinearity = gOrig;
  if (initState == FICA_INIT_GUESS && guess.n_rows != whiteningMatrix.n_cols) {
    initialStateMode = 0;
  } else if (guess.n_cols < numOfIC) {
    mat guess2;
    guess2.randu(guess.n_rows, numOfIC - guess.n_cols);
    guess2 -= .5;
    guess = join_horiz( guess, guess2 );
  } else if (guess.n_cols > numOfIC) {
    guess = guess.head_cols(guess.n_cols - 1);
    guess = guess.head_rows(guess.n_rows - 1);
  }

  if (approach == FICA_APPROACH_SYMM) {
    // skip
  } else {
    A.zeros(whiteningMatrix.n_cols, numOfIC);
    mat B; B.zeros(vectorSize, numOfIC);
    W = trans(B) * whiteningMatrix;
    int round = 1;
    int numFailures = 0;
    while (round <= numOfIC) {
      myy = myyOrig;
      usedNlinearity = gOrig;
      stroke = 0;

      notFine = 1;
      loong = 0;
      int endFinetuning = 0;

      vec w; w.zeros(vectorSize);
      if (initialStateMode == 0) {
        w.randu(vectorSize);
        w -= 0.5;
      } else {
        w = whiteningMatrix * guess.col(round);
      }

      w = w - B * trans(B) * w;

      w /= norm(w);

      vec wOld; wOld.zeros(vectorSize);
      vec wOld2; wOld2.zeros(vectorSize);

      int i = 1;
      int gabba = 1;

      while (i <= maxNumIterations + gabba) {

        w = w - B * trans(B) * w;
        w /= norm(w);

        if (notFine) {
          if (i == maxNumIterations + 1) {
            round--;
            numFailures++;
            if (numFailures > failureLimit) {
              if (round == 0) {
                A = dewhiteningMatrix * B;
                W = trans(B) * whiteningMatrix;
              } // if round
              return false;
            } // if numfailures > failurelimit
            break;
          } // if i == maxNumIterations + 1
        } // notFine
        else if (i >= endFinetuning) {
          wOld = w;
        }
        if (norm(w - wOld) < epsilon || norm(w + wOld) < epsilon) {
          if (fineTuningEnabled && notFine) {
            notFine = 0;
            gabba = maxFinetune;
            wOld.zeros(vectorSize);
            wOld2.zeros(vectorSize);
            usedNlinearity = gFine;
            myy = myyK * myyOrig;
            endFinetuning = maxFinetune + i;
          } // if finetuning
          else {
            numFailures = 0;
            B.col(round-1) = w;
            A.col(round-1) = dewhiteningMatrix * w;
            W.row(round-1) = conv_to<rowvec>::from(trans(whiteningMatrix) * w);
            break;
          } // ELSE finetuning
        } // if epsilon
        else if (stabilizationEnabled) {
          if (stroke == 0.0 &&
              (norm(w - wOld2) < epsilon || norm(w + wOld2) < epsilon)) {
            stroke = myy;
            myy /= 2.0;
            if (usedNlinearity % 2 == 0) {
              usedNlinearity++;
            } // IF MOD
          } // if !stroke
          else if (stroke != 0.0) {
            myy = stroke;
            stroke = 0.0;
            if (myy == 1 && (usedNlinearity % 2 != 0)) {
              usedNlinearity--;
            }
          } // if stroke
          else if (notFine && !loong && i > maxNumIterations / 2) {
            loong = 1;
            myy /= 2.0;
            if (usedNlinearity % 2 == 0) {
              usedNlinearity++;
            } // if mod
          } // if notfine
        } // If stabilization

        wOld2 = wOld;
        wOld = w;

        switch (usedNlinearity) {
        case FICA_NONLIN_POW3 : {
          w = (X * pow(trans(X) * w, 3)) / numSamples - 3 * w;
          break;
        }
        case (FICA_NONLIN_POW3+1) : {
          vec Y = trans(X) * w;
          vec Gpow3 = X * pow(Y, 3) / numSamples;
          double Beta = dot(w, Gpow3);
          w = w - myy * (Gpow3 - Beta * w) / (3 - Beta);
          break;
        }
        case (FICA_NONLIN_POW3+2) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          w = (Xsub * pow(trans(Xsub) * w, 3)) / Xsub.n_cols - 3 * w;
          break;
        }
        case (FICA_NONLIN_POW3+3): {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec Gpow3 = Xsub * pow(trans(Xsub) * w, 3) / (Xsub.n_cols);
          double Beta = dot(w, Gpow3);
          w = w - myy * (Gpow3 - Beta * w) / (3 - Beta);
          break;
        }
        // TANH
        case FICA_NONLIN_TANH : {
          vec hypTan = tanh(a1 * trans(X) * w);
          // TODO sum
          rowvec temp = sum(1 - pow(hypTan, 2));
          w = (X * hypTan - a1 * temp(0) * w) / numSamples;
          break;
        }
        case(FICA_NONLIN_TANH+1) : {
          vec Y = trans(X) * w;
          vec hypTan = tanh(a1 * Y);
          double Beta = dot(w, X * hypTan);
          rowvec temp = sum(1 - pow(hypTan, 2));
          w = w - myy * ((X * hypTan - Beta * w) / (a1 * temp(0)) - Beta);
          break;
        }
        case(FICA_NONLIN_TANH+2) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec hypTan = tanh(a1 * trans(Xsub) * w);
          rowvec temp = sum(1 - pow(hypTan, 2));
          w = (Xsub * hypTan - a1 * temp(0) * w) / Xsub.n_cols;
          break;
        }
        case(FICA_NONLIN_TANH+3) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec hypTan = tanh(a1 * trans(Xsub) * w);
          double Beta = dot(w, Xsub * hypTan);
          rowvec temp = sum(1 - pow(hypTan, 2));
          w = w - myy * ((Xsub * hypTan - Beta * w) / (a1 * temp(0) - Beta));
          break;
        }

        // GAUSS
        case FICA_NONLIN_GAUSS : {
          vec u = trans(X) * w;
          vec Usquared = pow(u, 2);
          vec ex = exp(-a2 * Usquared / 2);
          vec gauss = elem_mult(u, ex); // elem_mult??
          vec dGauss = elem_mult(1 - a2 * Usquared, ex);
          w = (X * gauss - sum(dGauss) * w) / numSamples;
          break;
        }
        case(FICA_NONLIN_GAUSS+1) : {
          vec u = trans(X) * w;
          vec Usquared = pow(u, 2);
          vec ex = exp(-a2 * Usquared / 2);
          vec gauss = elem_mult(u, ex);
          vec dGauss = elem_mult(1 - a2 * Usquared, ex);
          double Beta = dot(w, X * gauss);
          w = w - myy * ((X * gauss - Beta * w) / (sum(dGauss) - Beta));
          break;
        }
        case(FICA_NONLIN_GAUSS+2) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec u = trans(Xsub) * w;
          vec Usquared = pow(u, 2);
          vec ex = exp(-a2 * Usquared / 2);
          vec gauss = elem_mult(u, ex);
          vec dGauss = elem_mult(1 - a2 * Usquared, ex);
          w = (Xsub * gauss - sum(dGauss) * w) / Xsub.n_cols;
          break;
        }
        case(FICA_NONLIN_GAUSS+3) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec u = trans(Xsub) * w;
          vec Usquared = pow(u, 2);
          vec ex = exp(-a2 * Usquared / 2);
          vec gauss = elem_mult(u, ex);
          vec dGauss = elem_mult(1 - a2 * Usquared, ex);
          double Beta = dot(w, Xsub * gauss);
          w = w - myy * ((Xsub * gauss - Beta * w) / (sum(dGauss) - Beta));
          break;
        }

        // SKEW
        case FICA_NONLIN_SKEW : {
          w = (X * (pow(trans(X) * w, 2))) / numSamples;
          break;
        }
        case(FICA_NONLIN_SKEW+1) : {
          vec Y = trans(X) * w;
          vec Gskew = X * pow(Y, 2) / numSamples;
          double Beta = dot(w, Gskew);
          w = w - myy * (Gskew - Beta * w / (-Beta));
          break;
        }
        case(FICA_NONLIN_SKEW+2) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          w = (Xsub * (pow(trans(Xsub) * w, 2))) / Xsub.n_cols;
          break;
        }
        case(FICA_NONLIN_SKEW+3) : {
          mat Xsub = X.cols(getSamples(numSamples, sampleSize));
          vec Gskew = Xsub * pow(trans(Xsub) * w, 2) / Xsub.n_cols;
          double Beta = dot(w, Gskew);
          w = w - myy * (Gskew - Beta * w) / (-Beta);
          break;
        }
        } // switch linearity

        w /= norm(w);
        i++;

      } // while i <= maxNumIterations + gabba
      round++;
    } // while round <= numOfIC
  }
  return true;
}

static uvec getSamples(const int max, const double percentage)
{
  vec rd; rd.randu(max);
  //vec sV(max);
  uvec out;
  int sZ = 0;
  for (int i = 0; i < max; i++) {
    if (rd(i) < percentage) {
      //sV(sZ) = i;
      out << i;
      sZ++;
    }
  }
  //(sV.head(sZ));
  return (out);
}

mat Fast_ICA::get_independent_components() { if (PCAonly) { mat x; return(x.zeros(1, 1)); } else return icasig; }
void Fast_ICA::set_nrof_independent_components(int in_nrIC) { numOfIC = in_nrIC; }
void Fast_ICA::set_non_linearity(int in_g) { g = in_g; }
void Fast_ICA::set_approach(int in_approach) { approach = in_approach; if (approach == FICA_APPROACH_DEFL) finetune = true; }

/*
int main()
{

  mat X;

  // std::ifstream file("../arma_in");
  // std::string line;


  // while(std::getline(file, line)) {
  //   float value;
  //   int cnt = 0;
  //   std::stringstream  lineStream(line);
  //   while (lineStream >> value) {
  //     X << value;
  //     cnt++;
  //   }
  //   X << endr;
  // }
  X.load("../arma_in");
  //X = trans(X);
  cout << size(X) << endl;
  std::clock_t    start;
  start = std::clock();
  int trials = 1000;
  while (trials--) {
    Fast_ICA ica(X);
    ica.set_nrof_independent_components(3);
    ica.set_non_linearity(FICA_NONLIN_TANH);
    ica.set_approach( FICA_APPROACH_DEFL );
    ica.separate();
  }
  std::cout << "Time: " << (std::clock() - start) / (double)(CLOCKS_PER_SEC / 1000) << " ms" << std::endl;
  //mat ICs = ica.get_independent_components();
  return 0;
}*/
