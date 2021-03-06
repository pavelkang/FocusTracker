#ifndef ARMAICA_H
#define ARMAICA_H

#include "armadillo"

#define FICA_APPROACH_DEFL 2
#define FICA_APPROACH_SYMM 1
#define FICA_NONLIN_POW3 10
#define FICA_NONLIN_TANH 20
#define FICA_NONLIN_GAUSS 30
#define FICA_NONLIN_SKEW 40
#define FICA_INIT_RAND 0
#define FICA_INIT_GUESS 1
#define FICA_TOL 1e-9

class Fast_ICA
{
public:
  Fast_ICA(arma::mat ma_mixed_sig);
  bool separate();
  arma::mat get_independent_components();
  void set_nrof_independent_components(int in_nrIC);
  void set_non_linearity(int in_g);
  void set_approach(int in_approach);
private:
  int approach, numOfIC, g, initState;
  bool finetune, stabilization, PCAonly;
  double a1, a2, mu, epsilon, sampleSize;
  int maxNumIterations, maxFineTune;
  int firstEig, lastEig;
  arma::mat initGuess;

  arma::mat mixedSig, A, W, icasig;

  arma::mat whiteningMatrix;
  arma::mat dewhiteningMatrix;
  arma::mat whitesig;
  arma::mat E, VecPr;
  arma::vec D;
};


#endif
