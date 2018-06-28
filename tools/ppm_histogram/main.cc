////////////////////////////////////////////////////////////////////////////////
// This file scans a ppm file and generates a histogram of known colors. It then
// verifies that there is enough pixels of red and black for this image to be
// a valid display of the fuchsia dashboard. It prints either success or failure
// based upon that result.
//
// Usage:
//   ppm_histogram <ppm_file_path>
// Output (written to stdout):
// If the file is all black
//   failure
//   black: <number>, white: <number>, green <number>, red <number>
// For a properly displayed dashboard, something like
//   success

#include <stdio.h>
#include <string.h>
#include <map>

void printUsageError() {
  printf("ERROR: missing image file\n");
  printf("  USAGE: ppm_histogram <ppm_image_file>\n");
  printf("  ppm_image_file is expected to be binary RGB format.\n");
}

void printFileNotFoundError(const char *filePath) {
  printf("ERROR: file not found: %s\n", filePath);
}

void printImageFormatError(const char *errorMsg) {
  printf("ERROR: image file must be ppm binary RGB format.\n");
  printf("%s\n", errorMsg);
  printf("  Format P6 from https://en.wikipedia.org/wiki/Netpbm_format\n");
}

int readImageHeader(FILE *file, int &width, int &height) {
  // Expect to find P6 indicating binary RGB format
  char buf[255];
  fgets(buf, 3, file);
  if (strcmp(buf, "P6")) {
    printImageFormatError("P6 not first line");
    printf("Line was '%s'", buf);
    return 10;
  }
  int readValue;
  int result;

  // Width
  result = fscanf(file, "%i", &readValue);
  if (result != 1) {
    printImageFormatError("Couldn't read width");
    printf("result was %d, readValue was %d\n", result, readValue);
    return 11;
  }
  width = readValue;

  // Height
  result = fscanf(file, "%i", &readValue);
  if (result != 1) {
    printImageFormatError("Couldn't read height");
    printf("result was %d, readValue was %d\n", result, readValue);
    return 12;
  }
  height = readValue;

  // Depth must be 255
  result = fscanf(file, "%i", &readValue);
  if (result != 1) {
    printImageFormatError("Couldn't read depth");
    printf("result was %d, readValue was %d\n", result, readValue);
    return 13;
  }
  if (255 != readValue) {
    printImageFormatError("Depth was not 8 bit RGB");
    printf("result was %d, readValue was %d\n", result, readValue);
    return 14;
  }
  // Consume the newline after the header
  fgetc(file);

  return 0;
}

int readImageFile(FILE *file, std::map<int, int> &map)
{
  int width = 0;
  int height = 0;
  int result;
  result = readImageHeader(file, width, height);
  if (result) {
    return result;
  }

  unsigned char buffer[4];
  int numRead;
  unsigned int rgbValue;
  for (int row = 0; row < height; row++) {
    for (int column = 0; column < width; column++) {
      numRead = fread(buffer, 1, 3, file);
      if (numRead != 3) {
        printImageFormatError("Error reading image data");
        return 20;
      }
      rgbValue = (buffer[0] << 16) + (buffer[1] << 8) + buffer[2];
      if (map.find(rgbValue) != map.end()) {
        map[rgbValue] = map[rgbValue] + 1;
      } else {
        map[rgbValue] = 1;
      }
    }
  }
  return result;
}

// These are the only values we want to track
const int black = 0x000000;
const int white = 0xeeeeee;
const int green = 0x4dac26;
const int red = 0xd01c8b;

int main(int argc, const char **argv) {
  if (argc != 2) {
    printUsageError();
    return 1;
  }

  const char *fileName = argv[1];
  FILE *file = fopen(fileName, "r");
  if (file == NULL) {
    printFileNotFoundError(fileName);
    return 2;
  }

  std::map<int, int> histogram;
  int result = readImageFile(file, histogram);
  fclose(file);
  if (result) {
    return result;
  }

  // For success, there should be at least 1M green or red pixels combined
  // The typical number is > 1.5M
  if (histogram[green] + histogram[red] > 1000000) {
    printf("success\n");
    return 0;
  } else {
    printf("failure\n");
    printf("black: %d, white: %d, green: %d, red: %d\n",
        histogram[black], histogram[white], histogram[green], histogram[red]);
    // To help debug failures, if the majority of values aren't already covered
    // output the values that were over a threshold count.
    if (histogram[black]+ histogram[white]+ histogram[green]+
        histogram[red] < 1000000) {
      const int MIN_REPORT_THRESHOLD = 50000;
      std::map<int, int>::iterator it;
      for (it = histogram.begin(); it != histogram.end(); it++) {
        if (it->second > MIN_REPORT_THRESHOLD) {
          printf("Pixel 0x%06x occurred %d times\n", it->first, it->second);
        }
      }
    }
    return 30;
  }
}
