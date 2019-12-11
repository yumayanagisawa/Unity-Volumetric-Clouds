// How to make the colour array was found here https://www.shadertoy.com/view/4sfGzS
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class RuntimeTextureGenerator : MonoBehaviour
{
    public Material mat;
    // Start is called before the first frame update
    void Start()
    {
        Texture2D texture = new Texture2D(256, 256, TextureFormat.ARGB32, false);

        // make a color array, set the pixel values
        Color[,] colour = new Color[256, 256];
        for (int y = 0; y < 256; y++)
        {
            for (int x = 0; x < 256; x++)
            {
                colour[x, y].r = Random.value;
                colour[x, y].b = Random.value;
            }
        }

        for (int y = 0; y < 256; y++)
        {
            for (int x = 0; x < 256; x++)
            {
                int x2 = (x - 37) & 255;
                int y2 = (y - 17) & 255;
                //colour[x][y].g = colour[x2][y2].r;
                //colour[x][y].a = colour[x2][y2].b;
                colour[x,y].g = colour[x2,y2].r;
                colour[x,y].a = colour[x2,y2].b;
            }
        }

        for (int y = 0; y < 256; y++)
        {
            for (int x = 0; x < 256; x++)
            {
                texture.SetPixel(x, y, colour[x,y]);
            }
        }

        // Apply all SetPixel calls
        texture.Apply();

        // connect texture to material of GameObject this script is attached to
        //renderer.material.mainTexture = texture;
        gameObject.GetComponent<Renderer>().material.SetTexture("iChannel0", texture);
    }

    // Update is called once per frame
    void Update()
    {
        
    }
}
