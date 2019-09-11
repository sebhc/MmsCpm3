// Copyright (c) 2019 Douglas Miller <durgadas311@gmail.com>

import java.util.Vector;
import java.io.*;

public class mknetboot {
	private static void help() {
		System.err.format(
			"Usage: mknetboot [options] <spr-file>...\n"+
			"Options:\n" +
			"    -b       = next spr-file is BNK instead of RES\n" +
			"    -<type>  = next spr-file is <type>\n" +
			"               { \"bios\", \"bdos\", \"snios\", \"ndos\" }\n" +
			"    -o file  = output file name, else first spr-file.sys\n"
			);
		System.exit(1);
	}

	public static void main(String[] args) {
		Vector<SprFile> files;
		boolean banked = false;
		int type = 0;
		int ent = 0;
		int com = 0xc0; // TODO: configurable...
		String outfile = "out.sys";

		files = new Vector<SprFile>();
		int x = 0;
		for (; x < args.length; ++x) {
			if (args[x].equals("-b")) {
				banked = true;
			} else if (args[x].equals("-o")) {
				++x;
				if (x < args.length) {
					outfile = args[x];
				}
			} else if (args[x].startsWith("-")) {
				if (SprFile.isReloc(args[x].substring(1))) {
					type = SprFile.getReloc(args[x].substring(1));
				} else {
					System.err.format("Unrecognized option: %s\n",
						args[x]);
				}
			} else {
				File f = new File(args[x]);
				if (!f.exists() || f.isDirectory()) {
					System.err.format("No file \"%s\"\n", f.getAbsolutePath());
					System.exit(1);
				}
				SprFile spr = new SprFile(f, banked, type);
				files.add(spr);
				banked = false;
				type = 0;
			}
		}
		if (files.size() == 0) {
			help(); // does not return
		}
		// TODO: choose 'entry'...
		ent = files.size() - 1;
		SysFile sys = new SysFile(files, 0x00, com, ent);
		// TODO: check failure...
		sys.combine();
		if (sys.writeSys(new File(outfile))) {
			System.err.format("Wrote file \"%s\"\n", outfile);
		} else {
			System.exit(1);
		}
	}
}
