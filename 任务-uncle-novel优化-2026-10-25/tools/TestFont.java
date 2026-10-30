import javafx.scene.text.Font;
import java.io.File;

public class TestFont {
    public static void main(String[] args) throws Exception {
        for (String f : args) {
            File file = new File(f);
            try {
                String url = file.toURI().toURL().toExternalForm();
                Font ft = Font.loadFont(url, 12.0);
                System.out.println("URL=" + url);
                System.out.println("  -> " + (ft == null ? "NULL" : (ft.getFamily() + " / " + ft.getName())));
            } catch (Throwable t) {
                System.out.println("URL=" + file.toURI());
                System.out.println("  -> ERROR " + t);
            }
        }
    }
}
