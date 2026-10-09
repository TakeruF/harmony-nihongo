package com.takeruf.imecompareprobe;
import android.app.Activity;
import android.os.Bundle;
import android.content.*;
import android.graphics.Color;
import android.view.*;
import android.view.inputmethod.*;
import android.widget.*;
import android.text.*;
public class MainActivity extends Activity {
 EditText input; TextView output; int actionCount=0;
 int dp(int n){return (int)(getResources().getDisplayMetrics().density*n+.5f);}
 public void onCreate(Bundle b){super.onCreate(b);LinearLayout root=new LinearLayout(this);root.setOrientation(1);root.setPadding(dp(16),dp(36),dp(16),0);root.setBackgroundColor(Color.WHITE);
 TextView title=new TextView(this);title.setText("日本語フリック比較");title.setTextSize(22);root.addView(title);
 HorizontalScrollView scroll=new HorizontalScrollView(this);LinearLayout modes=new LinearLayout(this);scroll.addView(modes);root.addView(scroll);
 String[] names={"通常","検索","数字","パスワード","URL","メール"};for(int i=0;i<names.length;i++){final int mode=i;Button button=new Button(this);button.setText(names[i]);button.setOnClickListener(v->configure(mode));modes.addView(button);}
 input=new EditText(this);input.setContentDescription("comparison-input");input.setTextSize(22);input.setMinLines(3);input.setGravity(Gravity.TOP);root.addView(input,new LinearLayout.LayoutParams(-1,dp(150)));
 LinearLayout commands=new LinearLayout(this);root.addView(commands);Button clear=new Button(this);clear.setText("クリア");clear.setOnClickListener(v->input.setText(""));commands.addView(clear);Button clip=new Button(this);clip.setText("比較用テキストをコピー");clip.setOnClickListener(v->((android.content.ClipboardManager)getSystemService(CLIPBOARD_SERVICE)).setPrimaryClip(ClipData.newPlainText("比較","今日はいい天気です 😀\n二行目")));commands.addView(clip);
 output=new TextView(this);output.setTextSize(16);output.setContentDescription("comparison-value");root.addView(output);
 input.addTextChangedListener(new TextWatcher(){public void beforeTextChanged(CharSequence s,int a,int c,int d){}public void onTextChanged(CharSequence s,int a,int b,int c){output.setText("値："+s);}public void afterTextChanged(Editable s){try(java.io.FileOutputStream f=openFileOutput("comparison-value.txt",MODE_PRIVATE)){f.write(s.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));}catch(java.io.IOException e){throw new RuntimeException(e);}}});
 input.setOnEditorActionListener((v,a,e)->{output.setText("アクション："+a+" 回数："+(++actionCount)+" 値："+input.getText());return true;});setContentView(root);configure(0);input.postDelayed(()->((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showSoftInput(input,InputMethodManager.SHOW_IMPLICIT),400);
 }
 void configure(int mode){input.setText("");input.setSingleLine(mode!=0);int type=InputType.TYPE_CLASS_TEXT;int action=EditorInfo.IME_ACTION_DONE;switch(mode){case 0:type|=InputType.TYPE_TEXT_FLAG_MULTI_LINE;action=EditorInfo.IME_ACTION_UNSPECIFIED;break;case 1:action=EditorInfo.IME_ACTION_SEARCH;break;case 2:type=InputType.TYPE_CLASS_NUMBER|InputType.TYPE_NUMBER_FLAG_DECIMAL;break;case 3:type|=InputType.TYPE_TEXT_VARIATION_PASSWORD;break;case 4:type|=InputType.TYPE_TEXT_VARIATION_URI;break;case 5:type|=InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS;break;}input.setInputType(type);input.setImeOptions(action);input.requestFocus();((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).restartInput(input);((InputMethodManager)getSystemService(INPUT_METHOD_SERVICE)).showSoftInput(input,InputMethodManager.SHOW_IMPLICIT);}
}