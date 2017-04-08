#include "opencv2/highgui/highgui.hpp"
#include "opencv2/imgproc/imgproc.hpp"
#include <iostream>
#include <stdio.h>
#include <vector>
using namespace cv;
using namespace std;

typedef pair<int, int> indexpair;

bool comparator_indexpair_desc(
  const indexpair &l,
  const indexpair &r
  ) {
  return r.first < l.first;
}

void vp(vector<float> v) {
  cout << "----v----" << endl;
  for (int i = 0; i < v.size(); i++) {
    cout << v[i] << endl;
  }
  cout << "---------" << endl;
}

void MeanRemoval(
  Mat &input,
  int n,
  int T
  ) {
  for (int i = 0; i < n; i++) {
    double sum = 0.0;
    for (int t = 0; t < T; t++) {
      sum += input.at<float>(i, t);
    }
    sum /= T;
    float *ptr = (float *)input.data;
    for (int t = 0; t < T; t++) {
      *(float *)(ptr + i * T + t) -= sum;
    }
  }
}

void matrix_reorder(
  Mat &reorderedEigVecs,
  const Mat &eigVecs,
  const vector<int> &PCAindices,
  int n) {
  float *ptr = (float *)reorderedEigVecs.data;
  int m = PCAindices.size();
  for (int i = 0; i < PCAindices.size(); ++i) {
    int ind = PCAindices[i];
    // eigVecs.col(i) = eigVecs.col(ind)
    for (int j = 0; j < n; ++j) {
      *(float *)(ptr + m * j + i) = eigVecs.at<float>(j, ind);
    }
  }
}

void jade (
  Mat &output,
  const Mat &input_o, // n x T matrix with n sensors(n = 3 for RGB), T samples
  int n,
  int T,
  int m = 3 // output dimension, default to 3
  ) {
  Mat input = input_o.clone(); // optimize this later
  Size sz = input.size();
  assert(sz.height == n && sz.width == T);
  // 1. Mean Removal
  // For each sample, calculate the mean from m sensor inputs and remove
  MeanRemoval(input, n, T);
  // 2. whitening
  //   2.1 eigen basis for sample covariance matrix
  Mat eigValues, eigVecs, inputT;
  transpose(input, inputT);
  eigen(input * inputT / float(T), eigValues, eigVecs);
  cout << eigValues << endl;
  cout << eigVecs << endl;
  vector<float> eigValues_vec;
  eigValues_vec.assign((float *)eigValues.datastart, (float *)eigValues.dataend);
  vector< indexpair >eigValuesPairs;
  for (int i = 0; i < eigValues_vec.size(); ++i) {
    eigValuesPairs.push_back(make_pair(eigValues_vec[i], i));
  }
  sort(eigValuesPairs, comparator_indexpair_desc);
  vector<int> PCAindices;
  for (int i = 0; i < m; ++i) {
    PCAindices.push_back(eigValuesPairs[i].second);
  }
  Mat reorderedEigVecs(n, m, DataType<float>::type);
  matrix_reorder(reorderedEigVecs, eigVecs, PCAindices, n);
  // B does PCA on m components
  Mat B;
  cout << eigVecs << endl;
  transpose(reorderedEigVecs, B);
  cout << "B" << endl;
  cout << B << endl;
  Mat diagScales(m, m, DataType<float>::type);
  float *diagPtr = (float *)diagScales.data;
  for (int i = 0; i < m; ++i) {
    *(float *)(diagPtr + i * m + i) = 1.f/sqrt(eigValues_vec[PCAindices[i]]);
  }
  B = diagScales * B;
  input = B * input;
  // B is the whitening matrix, X is white
  cout << B << endl;
  cout << input << endl;
}

int main( int argc, char** argv )
{
  float test_data[15] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15};
  int T = 5;
  int n = 3;
  Mat test_mat = Mat(n, T, DataType<float>::type, test_data);
  Mat output;
  jade(output, test_mat, n, T);
  return 0;
}
