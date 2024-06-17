#! /usr/bin/env python3

''' read_sniffer: guess the Illumina machine from the read IDs '''


import argparse
import gzip
from pathlib import Path, PurePath
import re


__prog__ = 'read_sniffer'
__version__ = '0.1'

# globals #####################################################################

InstrumentIDs = {
    'HWUSI': ('GAIIx',),
    '(HWI-)?M[0-9]{4,5}': ('MiSeq',),
    '(HWI-)?C[0-9]{5}': ('HiSeq', '1500'),
    '(HWI-)?D[0-9]{5}': ('HiSeq', '2000/2500'),
    'SN[0-9]{3,4}': ('HiSeq', '2000/2500'),
    'J[0-9]{5}': ('HiSeq', '3000'),
    'K[0-9]{5}': ('HiSeq', '3000/4000'),
    '(ST-)?E[0-9]{5}': ('HiSeq', 'X'),
    'N[0-9]{4}': ('NextSeq', '500/550'),
    'VL[0-9]{5}': ('NextSeq', '1000'),
    'VH[0-9]{5}': ('NextSeq', '2000'),
    'N[BS][0-9]{6}': ('NextSeq',),
    'MN[0-9]{5}': ('MiniSeq',),
    'A[0-9]{5}': ('NovaSeq',),
    'H[0-9]{6}': ('NovaSeq',),
    'NA[0-9]{5}': ('NovaSeq',),
    'FS[0-9]{4}': ('iSeq', '100')
}

# argparse ####################################################################

parser = argparse.ArgumentParser(
    prog=__prog__,
    description='Guess the Illumina machine from the read IDs')
parser.add_argument(
    'file', type=Path, help='Sequencing file')
parser.add_argument(
    '-v', '--version', action='version', version=__version__)

# main ########################################################################

def main():

    args = parser.parse_args()
    
    reader = gzip.open if PurePath(args.file).suffix == '.gz' else open
    with reader(args.file, 'rt') as F:
        read_id = F.readline().strip()

    matched = False
    for pattern, instrument in InstrumentIDs.items():
        if re.search(f'{pattern}:', read_id) is not None:
            matched = True
            break
    if matched:
        print(instrument[0])
    else:
        print('Unknown')

###############################################################################

if __name__ == '__main__':
    main()