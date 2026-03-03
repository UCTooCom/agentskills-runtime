import java.io.*;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;

public class GenerateChecksums {
    public static void main(String[] args) {
        String directory = "D:\\UCT\\projects\\miniapp\\qintong\\Delivery\\uctoo-admin\\apps\\agentskills-runtime\\sdk\\java\\deploy\\com\\opencangjie\\agentskills-runtime\\0.0.1";
        String[] files = {
            "agentskills-runtime-0.0.1.jar",
            "agentskills-runtime-0.0.1-sources.jar",
            "agentskills-runtime-0.0.1-javadoc.jar",
            "agentskills-runtime-0.0.1.pom"
        };

        for (String fileName : files) {
            String filePath = directory + "\\" + fileName;
            generateChecksum(filePath, "MD5");
            generateChecksum(filePath, "SHA1");
        }

        System.out.println("校验和文件生成完成！");
    }

    private static void generateChecksum(String filePath, String algorithm) {
        try {
            File file = new File(filePath);
            MessageDigest digest = MessageDigest.getInstance(algorithm);
            FileInputStream fis = new FileInputStream(file);
            byte[] byteArray = new byte[1024];
            int bytesCount = 0;

            while ((bytesCount = fis.read(byteArray)) != -1) {
                digest.update(byteArray, 0, bytesCount);
            }
            fis.close();

            byte[] bytes = digest.digest();
            StringBuilder sb = new StringBuilder();
            for (int i = 0; i < bytes.length; i++) {
                sb.append(Integer.toString((bytes[i] & 0xff) + 0x100, 16).substring(1));
            }

            String checksum = sb.toString();
            String outputFile = filePath + "." + algorithm.toLowerCase();
            FileWriter writer = new FileWriter(outputFile);
            writer.write(checksum);
            writer.close();

            System.out.println(algorithm + " checksum for " + file.getName() + " generated: " + checksum);
        } catch (NoSuchAlgorithmException | IOException e) {
            e.printStackTrace();
        }
    }
}